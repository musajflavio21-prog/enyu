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

        // 重置状态
        isTracking = true
        pathCoordinates = []
        trackingDistance = 0
        trackingStartTime = Date()
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
        pathUpdateVersion += 1
    }

    /// 记录当前位置到路径
    private func recordCurrentPosition() {
        guard isTracking else { return }

        guard let currentLocation = userLocation else {
            print("⚠️ [圈地] 当前位置为空，跳过记录")
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

        print("📍 [圈地] 记录位置 #\(pathCoordinates.count): (\(String(format: "%.6f", currentLocation.latitude)), \(String(format: "%.6f", currentLocation.longitude)))")
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
