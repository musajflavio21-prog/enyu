//
//  LocationManager.swift
//  EarthLord
//
//  GPS定位管理器
//  负责请求定位权限、获取用户位置、处理授权状态变化
//

import Foundation
import CoreLocation
import Combine
import UIKit

/// GPS定位管理器
/// 使用 CoreLocation 框架获取用户位置
class LocationManager: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = LocationManager()

    // MARK: - 发布属性

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在定位
    @Published var isUpdatingLocation = false

    // MARK: - 路径追踪属性

    /// 是否正在追踪路径（圈地模式）
    @Published var isTracking = false

    /// 追踪的路径坐标数组
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 追踪开始时间
    @Published var trackingStartTime: Date?

    /// 追踪的总距离（米）
    @Published var trackingDistance: Double = 0

    // MARK: - 闭环检测属性

    /// 路径是否已闭环（走回起点）
    @Published var isPathClosed = false

    /// 闭环距离阈值（米）- 距离起点小于此值视为闭环
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数 - 至少需要这么多点才能判断闭环
    private let minimumPathPoints: Int = 10

    // MARK: - 速度检测属性

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed = false

    /// 当前速度（km/h）
    @Published var currentSpeed: Double = 0

    /// 上次位置记录时间
    private var lastLocationTimestamp: Date?

    /// 上次位置坐标
    private var lastRecordedLocation: CLLocationCoordinate2D?

    /// 速度警告阈值（km/h）
    private let speedWarningThreshold: Double = 15.0

    /// 速度停止阈值（km/h）- 超过此速度自动停止追踪
    private let speedStopThreshold: Double = 30.0

    // MARK: - 私有属性

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 路径追踪定时器
    private var trackingTimer: Timer?

    /// 最小记录距离（米）- 移动超过此距离才记录新点
    private let minTrackingDistance: Double = 10.0

    /// 追踪定时器间隔（秒）
    private let trackingInterval: TimeInterval = 2.0

    // MARK: - 计算属性

    /// 是否已获得定位授权
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被用户拒绝授权
    var isDenied: Bool {
        authorizationStatus == .denied
    }

    /// 是否是首次请求（未决定）
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    // MARK: - 初始化

    override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动10米才更新位置

        print("🗺️ [定位] LocationManager 初始化完成")
        print("🗺️ [定位] 当前授权状态: \(authorizationStatusDescription)")
    }

    // MARK: - 公开方法

    /// 请求定位权限
    func requestPermission() {
        print("🗺️ [定位] 请求定位权限...")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            print("⚠️ [定位] 未获得授权，无法开始定位")
            if isNotDetermined {
                requestPermission()
            }
            return
        }

        print("🗺️ [定位] 开始更新位置")
        isUpdatingLocation = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        print("🗺️ [定位] 停止更新位置")
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    /// 请求单次位置更新
    func requestLocation() {
        guard isAuthorized else {
            print("⚠️ [定位] 未获得授权，无法请求位置")
            return
        }

        print("🗺️ [定位] 请求单次位置")
        locationManager.requestLocation()
    }

    /// 打开系统设置页面
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - 路径追踪方法

    /// 开始路径追踪（圈地模式）
    func startPathTracking() {
        guard isAuthorized else {
            print("⚠️ [圈地] 未获得定位授权，无法开始圈地")
            return
        }

        guard !isTracking else {
            print("⚠️ [圈地] 已在追踪中")
            return
        }

        print("🏁 [圈地] 开始路径追踪")

        // 记录日志
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)

        // 重置状态
        isTracking = true
        pathCoordinates = []
        trackingDistance = 0
        trackingStartTime = Date()
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        currentSpeed = 0
        lastLocationTimestamp = nil
        lastRecordedLocation = nil
        pathUpdateVersion += 1

        // 确保定位服务正在运行
        if !isUpdatingLocation {
            startUpdatingLocation()
        }

        // 如果当前有位置，添加为起点
        if let currentLocation = userLocation {
            pathCoordinates.append(currentLocation)
            print("🏁 [圈地] 添加起点: (\(currentLocation.latitude), \(currentLocation.longitude))")
        }

        // 启动定时器，每隔一段时间记录位置
        trackingTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            self?.recordCurrentPosition()
        }
    }

    /// 停止路径追踪
    func stopPathTracking() {
        guard isTracking else {
            print("⚠️ [圈地] 未在追踪中")
            return
        }

        print("🏁 [圈地] 停止路径追踪，共记录 \(pathCoordinates.count) 个点")

        // 记录日志
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)

        // 停止定时器
        trackingTimer?.invalidate()
        trackingTimer = nil

        // 更新状态
        isTracking = false
        pathUpdateVersion += 1
    }

    /// 清除路径数据
    func clearPath() {
        print("🗑️ [圈地] 清除路径数据")
        pathCoordinates = []
        trackingDistance = 0
        trackingStartTime = nil
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        currentSpeed = 0
        lastLocationTimestamp = nil
        lastRecordedLocation = nil
        pathUpdateVersion += 1
    }

    // MARK: - 闭环检测方法

    /// 检查路径是否闭环（走回起点）
    private func checkPathClosure() {
        // 已经闭环则不再检测
        guard !isPathClosed else { return }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            print("🔄 [闭环] 点数不足：\(pathCoordinates.count) < \(minimumPathPoints)")
            return
        }

        // 获取起点和当前位置
        guard let startPoint = pathCoordinates.first,
              let currentPoint = pathCoordinates.last else {
            return
        }

        // 计算当前位置到起点的距离
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        let distanceToStart = currentLocation.distance(from: startLocation)

        print("🔄 [闭环] 检测中... 距离起点: \(String(format: "%.1f", distanceToStart))m，阈值: \(closureDistanceThreshold)m")

        // 记录闭环检测日志
        TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distanceToStart))m (需≤30m)", type: .info)

        // 判断是否闭环
        if distanceToStart <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1
            print("✅ [闭环] 路径已闭环！距离起点 \(String(format: "%.1f", distanceToStart))m")

            // 记录闭环成功日志
            TerritoryLogger.shared.log("闭环成功！距起点 \(String(format: "%.1f", distanceToStart))m", type: .success)
        }
    }

    // MARK: - 速度检测方法

    /// 验证移动速度
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常可以继续，false 表示速度异常
    private func validateMovementSpeed(newLocation: CLLocationCoordinate2D) -> Bool {
        let now = Date()

        // 首次记录，初始化基准
        guard let lastTimestamp = lastLocationTimestamp,
              let lastLocation = lastRecordedLocation else {
            lastLocationTimestamp = now
            lastRecordedLocation = newLocation
            currentSpeed = 0
            return true
        }

        // 计算时间差（秒）
        let timeDiff = now.timeIntervalSince(lastTimestamp)
        guard timeDiff > 0 else { return true }

        // 计算距离（米）
        let lastCLLocation = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
        let newCLLocation = CLLocation(latitude: newLocation.latitude, longitude: newLocation.longitude)
        let distance = newCLLocation.distance(from: lastCLLocation)

        // 计算速度（km/h）
        let speedMps = distance / timeDiff  // 米/秒
        let speedKmh = speedMps * 3.6       // 转换为 km/h
        currentSpeed = speedKmh

        // 更新基准
        lastLocationTimestamp = now
        lastRecordedLocation = newLocation

        print("🏃 [速度] 当前速度: \(String(format: "%.1f", speedKmh)) km/h")

        // 超过停止阈值（30 km/h）- 自动停止追踪
        if speedKmh > speedStopThreshold {
            speedWarning = "速度过快（\(String(format: "%.0f", speedKmh)) km/h），已自动暂停追踪"
            isOverSpeed = true
            print("🚨 [速度] 超速停止！速度 \(String(format: "%.1f", speedKmh)) km/h > \(speedStopThreshold) km/h")

            // 记录超速停止日志
            TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speedKmh)) km/h，已停止追踪", type: .error)

            stopPathTracking()
            return false
        }

        // 超过警告阈值（15 km/h）
        if speedKmh > speedWarningThreshold {
            speedWarning = "移动速度较快（\(String(format: "%.0f", speedKmh)) km/h），请步行圈地"
            isOverSpeed = true
            print("⚠️ [速度] 速度警告！速度 \(String(format: "%.1f", speedKmh)) km/h > \(speedWarningThreshold) km/h")

            // 记录速度警告日志
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speedKmh)) km/h", type: .warning)

            return true  // 警告但继续记录
        }

        // 速度正常
        if isOverSpeed {
            speedWarning = nil
            isOverSpeed = false
            print("✅ [速度] 速度恢复正常")
        }

        return true
    }

    /// 记录当前位置到路径
    private func recordCurrentPosition() {
        guard isTracking else { return }

        guard let currentLocation = userLocation else {
            print("⚠️ [圈地] 当前位置为空，跳过记录")
            return
        }

        // 速度检测（放在距离检测之前）
        guard validateMovementSpeed(newLocation: currentLocation) else {
            print("🚨 [圈地] 速度异常，停止记录")
            return
        }

        // 检查是否需要记录（距离上一个点超过最小距离）
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let currentCLLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            let distance = currentCLLocation.distance(from: lastLocation)

            if distance < minTrackingDistance {
                print("📍 [圈地] 移动距离 \(String(format: "%.1f", distance))m < \(minTrackingDistance)m，跳过记录")
                return
            }

            // 累加距离
            trackingDistance += distance
        }

        // 记录新位置
        pathCoordinates.append(currentLocation)
        pathUpdateVersion += 1

        // 计算与上一点的距离（用于日志显示）
        let distanceFromLast: Double
        if pathCoordinates.count > 1 {
            let prevCoord = pathCoordinates[pathCoordinates.count - 2]
            let prevLocation = CLLocation(latitude: prevCoord.latitude, longitude: prevCoord.longitude)
            let currLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            distanceFromLast = currLocation.distance(from: prevLocation)
        } else {
            distanceFromLast = 0
        }

        print("📍 [圈地] 记录位置 #\(pathCoordinates.count): (\(String(format: "%.6f", currentLocation.latitude)), \(String(format: "%.6f", currentLocation.longitude)))")

        // 记录新点日志
        TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(String(format: "%.1f", distanceFromLast))m", type: .info)

        // 闭环检测
        checkPathClosure()
    }

    /// 获取追踪时长（格式化字符串）
    var trackingDurationString: String {
        guard let startTime = trackingStartTime else { return "00:00" }
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 获取追踪距离（格式化字符串）
    var trackingDistanceString: String {
        if trackingDistance < 1000 {
            return String(format: "%.0f 米", trackingDistance)
        } else {
            return String(format: "%.2f 公里", trackingDistance / 1000)
        }
    }

    // MARK: - 私有方法

    /// 授权状态描述
    private var authorizationStatusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "未决定"
        case .restricted:
            return "受限制"
        case .denied:
            return "已拒绝"
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用时允许"
        @unknown default:
            return "未知状态"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化回调
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        print("🗺️ [定位] 授权状态变化: \(authorizationStatusDescription) -> ", terminator: "")

        DispatchQueue.main.async {
            self.authorizationStatus = newStatus
            print(self.authorizationStatusDescription)

            // 如果刚获得授权，自动开始定位
            if self.isAuthorized && !self.isUpdatingLocation {
                self.startUpdatingLocation()
            }
        }
    }

    /// 位置更新回调
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let coordinate = location.coordinate
        print("🗺️ [定位] 获取到位置: (\(coordinate.latitude), \(coordinate.longitude))")

        DispatchQueue.main.async {
            self.userLocation = coordinate
            self.locationError = nil
        }
    }

    /// 定位失败回调
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [定位] 定位失败: \(error.localizedDescription)")

        DispatchQueue.main.async {
            // 区分错误类型
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "定位权限被拒绝，请在设置中开启"
                case .locationUnknown:
                    self.locationError = "无法获取位置，请稍后重试"
                case .network:
                    self.locationError = "网络错误，请检查网络连接"
                default:
                    self.locationError = "定位失败: \(error.localizedDescription)"
                }
            } else {
                self.locationError = "定位失败: \(error.localizedDescription)"
            }
        }
    }
}
