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

    // MARK: - 验证常量

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算出的领地面积（平方米）
    @Published var calculatedArea: Double = 0

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

    /// 速度警告阈值（km/h）- 15-30 km/h 显示警告但继续记录
    private let speedWarningThreshold: Double = 15.0

    /// 速度停止阈值（km/h）- 超过 30 km/h 停止追踪
    private let speedStopThreshold: Double = 30.0

    /// 速度检测预热点数 - 前几个点不检测速度（GPS 需要稳定）
    private let speedCheckWarmupPoints: Int = 3

    /// 连续超速计数 - 需要连续多次超速才触发
    private var consecutiveOverSpeedCount: Int = 0

    /// 触发警告需要的连续超速次数
    private let requiredConsecutiveOverSpeed: Int = 2

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
        consecutiveOverSpeedCount = 0
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        pathUpdateVersion += 1

        // 确保定位服务正在运行
        if !isUpdatingLocation {
            startUpdatingLocation()
        }

        // 如果当前有位置，添加为起点并初始化时间戳
        if let currentLocation = userLocation {
            pathCoordinates.append(currentLocation)
            lastLocationTimestamp = Date()
            lastRecordedLocation = currentLocation
            print("🏁 [圈地] 添加起点: (\(currentLocation.latitude), \(currentLocation.longitude))")
            TerritoryLogger.shared.log("添加起点", type: .info)
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

        // 更新状态（重置所有追踪相关的状态）
        isTracking = false
        pathCoordinates = []
        trackingDistance = 0
        trackingStartTime = nil
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        currentSpeed = 0
        lastLocationTimestamp = nil
        lastRecordedLocation = nil
        consecutiveOverSpeedCount = 0
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
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
        consecutiveOverSpeedCount = 0
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
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

            // 闭环后自动触发领地验证
            let validationResult = validateTerritory()
            territoryValidationPassed = validationResult.isValid
            territoryValidationError = validationResult.errorMessage
        }
    }

    // MARK: - 速度检测方法

    /// 验证移动速度（不更新时间戳，由调用方负责）
    /// - Parameters:
    ///   - newLocation: 新位置
    ///   - distance: 已计算的距离（米）
    /// - Returns: true 表示速度正常可以继续（包括警告范围），false 表示超速需停止
    private func validateMovementSpeed(newLocation: CLLocationCoordinate2D, distance: Double) -> Bool {
        let now = Date()

        // 首次记录，无法计算速度，允许通过
        guard let lastTimestamp = lastLocationTimestamp else {
            currentSpeed = 0
            print("🏃 [速度] 首次记录，跳过速度检测")
            return true
        }

        // 预热期：前几个点不检测速度（GPS 需要时间稳定）
        if pathCoordinates.count < speedCheckWarmupPoints {
            currentSpeed = 0
            print("🏃 [速度] 预热期，跳过速度检测（点数: \(pathCoordinates.count)/\(speedCheckWarmupPoints)）")
            TerritoryLogger.shared.log("GPS 预热中... (\(pathCoordinates.count)/\(speedCheckWarmupPoints))", type: .info)
            return true
        }

        // 计算时间差（秒）
        let timeDiff = now.timeIntervalSince(lastTimestamp)
        guard timeDiff > 0.5 else {
            // 时间间隔太短，跳过速度检测
            return true
        }

        // 计算速度（km/h）
        let speedMps = distance / timeDiff  // 米/秒
        let speedKmh = speedMps * 3.6       // 转换为 km/h
        currentSpeed = speedKmh

        print("🏃 [速度] 距离: \(String(format: "%.1f", distance))m, 时间: \(String(format: "%.1f", timeDiff))s, 速度: \(String(format: "%.1f", speedKmh)) km/h")
        TerritoryLogger.shared.log("速度: \(String(format: "%.1f", speedKmh)) km/h", type: .info)

        // 超过停止阈值（30 km/h）- 需要连续超速才停止
        if speedKmh > speedStopThreshold {
            consecutiveOverSpeedCount += 1
            print("🚨 [速度] 超速检测 \(consecutiveOverSpeedCount)/\(requiredConsecutiveOverSpeed)")

            if consecutiveOverSpeedCount >= requiredConsecutiveOverSpeed {
                speedWarning = "速度过快（\(String(format: "%.0f", speedKmh)) km/h），已自动暂停追踪"
                isOverSpeed = true
                print("🚨 [速度] 连续超速，停止追踪！")
                TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speedKmh)) km/h，已停止追踪", type: .error)
                stopPathTracking()
                return false
            } else {
                // 单次超速，可能是 GPS 漂移，只记录不停止
                TerritoryLogger.shared.log("疑似 GPS 漂移 \(String(format: "%.1f", speedKmh)) km/h，继续监测", type: .warning)
                return true
            }
        }

        // 警告范围（15-30 km/h）- 显示警告但继续记录
        if speedKmh > speedWarningThreshold {
            consecutiveOverSpeedCount += 1

            if consecutiveOverSpeedCount >= requiredConsecutiveOverSpeed {
                speedWarning = "移动速度较快（\(String(format: "%.0f", speedKmh)) km/h），请步行圈地"
                isOverSpeed = true
                print("⚠️ [速度] 连续速度警告！")
                TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speedKmh)) km/h", type: .warning)
            }
            return true  // 警告但继续记录
        }

        // 速度正常（< 15 km/h），重置连续超速计数
        consecutiveOverSpeedCount = 0
        if isOverSpeed {
            speedWarning = nil
            isOverSpeed = false
            print("✅ [速度] 速度恢复正常")
            TerritoryLogger.shared.log("速度恢复正常", type: .info)
        }

        return true
    }

    /// 记录当前位置到路径
    /// 正确顺序：1.距离检测 → 2.速度检测 → 3.记录点 → 4.闭环检测
    private func recordCurrentPosition() {
        guard isTracking else { return }

        guard let currentLocation = userLocation else {
            print("⚠️ [圈地] 当前位置为空，跳过记录")
            return
        }

        // ========== 第1步：距离检测 ==========
        // 首个点直接记录
        guard let lastCoordinate = pathCoordinates.last else {
            // 首个点：直接记录，初始化时间戳
            pathCoordinates.append(currentLocation)
            lastLocationTimestamp = Date()
            lastRecordedLocation = currentLocation
            pathUpdateVersion += 1
            print("📍 [圈地] 记录起点 #1: (\(String(format: "%.6f", currentLocation.latitude)), \(String(format: "%.6f", currentLocation.longitude)))")
            TerritoryLogger.shared.log("记录起点", type: .info)
            return
        }

        // 计算与上一个记录点的距离
        let lastCLLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let currentCLLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let distance = currentCLLocation.distance(from: lastCLLocation)

        // 距离不够，直接返回（不更新时间戳）
        if distance < minTrackingDistance {
            print("📍 [圈地] 移动距离 \(String(format: "%.1f", distance))m < \(minTrackingDistance)m，跳过记录")
            return
        }

        // ========== 第2步：速度检测（距离够了才检测速度）==========
        guard validateMovementSpeed(newLocation: currentLocation, distance: distance) else {
            print("🚨 [圈地] 速度异常，停止记录")
            return
        }

        // ========== 第3步：记录新点（距离和速度都通过）==========
        // 累加距离
        trackingDistance += distance

        // 记录新位置
        pathCoordinates.append(currentLocation)
        pathUpdateVersion += 1

        // 关键：只有在点被记录后，才更新时间戳
        lastLocationTimestamp = Date()
        lastRecordedLocation = currentLocation

        print("📍 [圈地] 记录位置 #\(pathCoordinates.count): (\(String(format: "%.6f", currentLocation.latitude)), \(String(format: "%.6f", currentLocation.longitude)))")
        TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(String(format: "%.1f", distance))m", type: .info)

        // ========== 第4步：闭环检测 ==========
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

    // MARK: - 距离与面积计算

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = pathCoordinates[i]
            let next = pathCoordinates[i + 1]

            let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let nextLocation = CLLocation(latitude: next.latitude, longitude: next.longitude)

            totalDistance += nextLocation.distance(from: currentLocation)
        }

        return totalDistance
    }

    /// 使用鞋带公式计算多边形面积（平面投影方法）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        // 使用第一个点作为参考点，将所有点转换为相对米坐标
        let referencePoint = pathCoordinates[0]
        let referenceLat = referencePoint.latitude * .pi / 180

        // 计算1度经纬度对应的米数（在参考点处）
        let metersPerDegreeLat: Double = 111320  // 纬度1度约等于111.32km
        let metersPerDegreeLon: Double = 111320 * cos(referenceLat)  // 经度1度随纬度变化

        // 将所有坐标点转换为以参考点为原点的米坐标
        var points: [(x: Double, y: Double)] = []
        for coord in pathCoordinates {
            let x = (coord.longitude - referencePoint.longitude) * metersPerDegreeLon
            let y = (coord.latitude - referencePoint.latitude) * metersPerDegreeLat
            points.append((x: x, y: y))
        }

        // 使用标准鞋带公式计算面积
        var area: Double = 0
        let n = points.count

        for i in 0..<n {
            let j = (i + 1) % n  // 下一个点（循环）
            area += points[i].x * points[j].y
            area -= points[j].x * points[i].y
        }

        area = abs(area / 2.0)
        return area
    }

    // MARK: - 自相交检测

    /// 判断两线段是否相交（CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1起点
    ///   - p2: 线段1终点
    ///   - p3: 线段2起点
    ///   - p4: 线段2终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        /// CCW 辅助函数：判断三点是否逆时针排列
        /// 坐标映射：longitude = X轴，latitude = Y轴
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            // 叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                               (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 判断逻辑：两线段相交当且仅当
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测路径是否存在自相交
    /// - Returns: true 表示存在自相交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量（防止正常圈地被误判）
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            // ✅ 循环内索引检查
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                // ✅ 循环内索引检查
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较（防止正常闭环被误判为自交）
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount
                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否有效
    /// - Returns: (isValid: 是否有效, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let error = "点数不足: \(pointCount)个 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(pointCount)个 ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let error = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(Int(minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let error = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        calculatedArea = area
        if area < minimumEnclosedArea {
            let error = "面积不足: \(String(format: "%.0f", area))m² (需≥\(Int(minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // 所有验证通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)
        return (true, nil)
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
