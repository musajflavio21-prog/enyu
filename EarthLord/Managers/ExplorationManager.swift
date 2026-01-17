//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器
//  负责探索状态管理、GPS追踪、距离计算、奖励生成
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 奖励等级
enum RewardTier: String, Codable, CaseIterable {
    case none = "none"          // 无奖励（<200米）
    case bronze = "bronze"      // 铜级（200-500米）
    case silver = "silver"      // 银级（500-1000米）
    case gold = "gold"          // 金级（1000-2000米）
    case diamond = "diamond"    // 钻石级（>2000米）

    /// 等级中文名称
    var displayName: String {
        switch self {
        case .none: return "无"
        case .bronze: return "铜级"
        case .silver: return "银级"
        case .gold: return "金级"
        case .diamond: return "钻石级"
        }
    }

    /// 等级图标
    var icon: String {
        switch self {
        case .none: return "xmark.circle"
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold: return "medal.fill"
        case .diamond: return "diamond.fill"
        }
    }

    /// 奖励物品数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 各稀有度概率 (common, rare, epic)
    var rarityProbabilities: (common: Double, rare: Double, epic: Double) {
        switch self {
        case .none: return (0, 0, 0)
        case .bronze: return (0.90, 0.10, 0.00)
        case .silver: return (0.70, 0.25, 0.05)
        case .gold: return (0.50, 0.35, 0.15)
        case .diamond: return (0.30, 0.40, 0.30)
        }
    }

    /// 根据距离确定等级
    static func from(distance: Double) -> RewardTier {
        switch distance {
        case ..<200: return .none
        case 200..<500: return .bronze
        case 500..<1000: return .silver
        case 1000..<2000: return .gold
        default: return .diamond
        }
    }
}

/// 探索会话数据模型（与数据库对应）
struct ExplorationSession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let startTime: Date
    var endTime: Date?
    var durationSeconds: Int
    var startLat: Double?
    var startLng: Double?
    var endLat: Double?
    var endLng: Double?
    var totalDistance: Double
    var rewardTier: String?
    var itemsRewarded: [RewardedItem]
    var status: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
        case startLat = "start_lat"
        case startLng = "start_lng"
        case endLat = "end_lat"
        case endLng = "end_lng"
        case totalDistance = "total_distance"
        case rewardTier = "reward_tier"
        case itemsRewarded = "items_rewarded"
        case status
    }
}

/// 奖励物品（用于 JSONB 存储）
struct RewardedItem: Codable, Identifiable {
    let id: String
    let itemId: String
    let quantity: Int
    let quality: String?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case quantity
        case quality
    }
}

/// 新建探索会话（用于插入）
struct NewExplorationSession: Codable {
    let id: String
    let userId: String
    let startLat: Double?
    let startLng: Double?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startLat = "start_lat"
        case startLng = "start_lng"
        case status
    }
}

/// 更新探索会话（用于更新）
struct UpdateExplorationSession: Codable {
    let endTime: String
    let durationSeconds: Int
    let totalDistance: Double
    let rewardTier: String
    let itemsRewarded: [RewardedItemForDB]
    let endLat: Double?
    let endLng: Double?
    let status: String

    enum CodingKeys: String, CodingKey {
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
        case totalDistance = "total_distance"
        case rewardTier = "reward_tier"
        case itemsRewarded = "items_rewarded"
        case endLat = "end_lat"
        case endLng = "end_lng"
        case status
    }
}

/// 奖励物品（用于数据库存储）
struct RewardedItemForDB: Codable {
    let id: String
    let itemId: String
    let quantity: Int
    let quality: String?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case quantity
        case quality
    }

    init(from reward: RewardedItem) {
        self.id = reward.id
        self.itemId = reward.itemId
        self.quantity = reward.quantity
        self.quality = reward.quality
    }
}

/// 新建背包物品（用于插入）
struct NewDBInventoryItem: Codable {
    let userId: String
    let itemId: String
    let quantity: Int
    let quality: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case quality
    }
}

/// 物品定义（从数据库加载）
struct DBItemDefinition: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let weight: Double
    let volume: Double
    let rarity: String
    let stackLimit: Int
    let description: String?
    let hasQuality: Bool
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, weight, volume, rarity
        case stackLimit = "stack_limit"
        case description
        case hasQuality = "has_quality"
        case icon
    }
}

/// 探索失败原因
enum ExplorationFailureReason {
    case overspeed  // 超速
    case cancelled  // 用户取消
    case error(String)  // 其他错误

    var displayMessage: String {
        switch self {
        case .overspeed:
            return "检测到您的移动速度超过30km/h，探索已自动停止。探索功能仅支持步行模式。"
        case .cancelled:
            return "探索已取消"
        case .error(let msg):
            return msg
        }
    }
}

/// 探索管理器
@MainActor
class ExplorationManager: ObservableObject {

    // MARK: - 单例

    static let shared = ExplorationManager()

    // MARK: - 发布属性

    /// 是否正在探索
    @Published var isExploring = false

    /// 当前累计距离（米）
    @Published var currentDistance: Double = 0

    /// 当前探索时长（秒）
    @Published var currentDuration: TimeInterval = 0

    /// 当前奖励等级（实时计算）
    @Published var currentTier: RewardTier = .none

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 物品定义缓存
    @Published var itemDefinitions: [DBItemDefinition] = []

    /// 最近一次探索结果
    @Published var lastExplorationResult: ExplorationResult?

    /// 当前速度（km/h）
    @Published var currentSpeed: Double = 0

    /// 是否超速警告中
    @Published var isOverspeedWarning = false

    /// 超速倒计时（秒）
    @Published var overspeedCountdown: Int = 0

    /// 探索是否因超速失败
    @Published var explorationFailed = false

    /// 探索失败原因
    @Published var failureReason: ExplorationFailureReason?

    // MARK: - POI 搜刮相关属性（Day22）

    /// 附近的POI列表
    @Published var nearbyPOIs: [RealPOI] = []

    /// 是否显示POI接近弹窗
    @Published var showPOIPopup = false

    /// 当前接近的POI
    @Published var currentProximityPOI: RealPOI? = nil

    /// 最近搜刮获得的物品
    @Published var lastScavengedItems: [LootRecord]? = nil

    // MARK: - 玩家密度相关属性（Day22+）

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published var densityTier: PlayerDensityTier = .solo

    /// 建议显示的POI数量
    private var recommendedPOICount: Int {
        return densityTier.recommendedPOICount
    }

    // MARK: - 私有属性

    /// 探索开始时间
    private var startTime: Date?

    /// 探索开始位置
    private var startLocation: CLLocationCoordinate2D?

    /// 上一次记录的位置
    private var lastLocation: CLLocation?

    /// 上一次记录时间
    private var lastLocationTime: Date?

    /// 计时器
    private var timer: Timer?

    /// 当前会话 ID
    private var currentSessionId: UUID?

    /// 超速开始时间
    private var overspeedStartTime: Date?

    /// 超速检测计时器
    private var overspeedTimer: Timer?

    /// 速度历史记录（用于平滑计算）
    private var speedHistory: [Double] = []

    /// 地理围栏管理（Day22 POI搜刮）
    private var monitoredRegions: [String: CLCircularRegion] = [:]  // poiId -> region

    /// 地理围栏触发半径（米）
    private let geofenceRadius: CLLocationDistance = 50

    /// 是否已搜索POI（避免重复搜索）
    private var hasSearchedPOIs = false

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        AuthManager.shared.supabaseClient
    }

    // MARK: - GPS 过滤常量

    /// 最大水平精度（米）- 精度超过此值忽略
    private let maxHorizontalAccuracy: Double = 50

    /// 最大位置跳变距离（米）
    private let maxJumpDistance: Double = 100

    /// 最小时间间隔（秒）
    private let minTimeInterval: TimeInterval = 1.0

    /// 最小移动距离（米）
    private let minMoveDistance: Double = 3.0

    // MARK: - 速度限制常量

    /// 最大允许速度（km/h）- 30km/h
    private let maxSpeedKmh: Double = 30.0

    /// 超速容忍时间（秒）
    private let overspeedToleranceSeconds: Int = 10

    /// 速度历史记录最大数量（用于平滑）
    private let maxSpeedHistoryCount: Int = 3

    // MARK: - 初始化

    private init() {
        log("ExplorationManager 初始化")
    }

    // MARK: - 日志方法

    /// 统一日志输出
    private func log(_ message: String, level: String = "INFO") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let prefix: String
        switch level {
        case "ERROR":
            prefix = "❌"
        case "WARN":
            prefix = "⚠️"
        case "DEBUG":
            prefix = "🔍"
        default:
            prefix = "🚶"
        }
        print("\(prefix) [\(timestamp)] [探索] \(message)")
    }

    // MARK: - 公开方法

    /// 加载物品定义
    func loadItemDefinitions() async {
        guard itemDefinitions.isEmpty else {
            log("物品定义已缓存，跳过加载", level: "DEBUG")
            return
        }

        log("开始加载物品定义...")

        do {
            let items: [DBItemDefinition] = try await supabase
                .from("item_definitions")
                .select()
                .execute()
                .value

            itemDefinitions = items
            log("成功加载 \(items.count) 种物品定义")
        } catch {
            log("加载物品定义失败: \(error)", level: "ERROR")
        }
    }

    /// 开始探索
    func startExploration() async {
        guard !isExploring else {
            log("已在探索中，忽略重复开始请求", level: "WARN")
            return
        }

        guard let userId = AuthManager.shared.currentUser?.id else {
            log("用户未登录，无法开始探索", level: "ERROR")
            errorMessage = "请先登录"
            return
        }

        // 加载物品定义
        await loadItemDefinitions()

        log("========== 开始新的探索 ==========")
        log("用户ID: \(userId.uuidString)")

        // 重置状态
        isExploring = true
        currentDistance = 0
        currentDuration = 0
        currentTier = .none
        currentSpeed = 0
        isOverspeedWarning = false
        overspeedCountdown = 0
        explorationFailed = false
        failureReason = nil
        startTime = Date()
        lastLocation = nil
        lastLocationTime = nil
        overspeedStartTime = nil
        speedHistory = []
        errorMessage = nil

        // 获取起始位置
        if let location = LocationManager.shared.userLocation {
            startLocation = location
            lastLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            lastLocationTime = Date()
            log("起始位置: (\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))")
        } else {
            log("警告: 无法获取起始位置", level: "WARN")
        }

        // 创建数据库记录
        do {
            let sessionId = UUID()
            currentSessionId = sessionId

            let newSession = NewExplorationSession(
                id: sessionId.uuidString,
                userId: userId.uuidString,
                startLat: startLocation?.latitude,
                startLng: startLocation?.longitude,
                status: "active"
            )

            try await supabase
                .from("exploration_sessions")
                .insert(newSession)
                .execute()

            log("创建探索会话成功: \(sessionId.uuidString)")
        } catch {
            log("创建探索会话失败: \(error)", level: "ERROR")
            // 即使数据库失败，仍然继续本地探索
        }

        // 启动计时器
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDuration()
            }
        }
        log("探索计时器已启动")

        // 确保定位服务运行
        if !LocationManager.shared.isUpdatingLocation {
            LocationManager.shared.startUpdatingLocation()
            log("定位服务已启动")
        } else {
            log("定位服务已在运行中", level: "DEBUG")
        }

        // Day22 POI搜刮：注册地理围栏回调
        LocationManager.shared.geofenceEntryCallback = { [weak self] poiId in
            self?.handleGeofenceEntry(poiId: poiId)
        }

        // Day22+ 玩家密度检测：启动位置上报
        PlayerDensityManager.shared.startLocationReporting()

        // Day22+ 玩家密度检测：延迟2秒后查询密度并搜索POI（确保GPS已稳定）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.queryDensityAndSearchPOIs()
        }
    }

    /// 处理新位置更新（由 LocationManager 调用）
    func handleLocationUpdate(_ location: CLLocation) {
        guard isExploring else { return }

        // 过滤条件1：精度检查
        if location.horizontalAccuracy > maxHorizontalAccuracy {
            log("GPS精度太差: \(String(format: "%.1f", location.horizontalAccuracy))m > \(maxHorizontalAccuracy)m，忽略此点", level: "DEBUG")
            return
        }

        // 过滤条件2：时间间隔检查
        guard let lastTime = lastLocationTime else {
            // 第一个点
            lastLocation = location
            lastLocationTime = location.timestamp
            log("记录第一个位置点: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))")
            return
        }

        let timeInterval = location.timestamp.timeIntervalSince(lastTime)
        if timeInterval < minTimeInterval {
            return // 静默跳过，太频繁
        }

        // 计算与上一点的距离
        guard let last = lastLocation else {
            lastLocation = location
            lastLocationTime = location.timestamp
            return
        }

        let distance = location.distance(from: last)

        // 计算瞬时速度 (m/s -> km/h)
        let instantSpeedMs = distance / timeInterval
        let instantSpeedKmh = instantSpeedMs * 3.6

        // 添加到速度历史（用于平滑）
        speedHistory.append(instantSpeedKmh)
        if speedHistory.count > maxSpeedHistoryCount {
            speedHistory.removeFirst()
        }

        // 计算平均速度（平滑处理）
        let averageSpeed = speedHistory.reduce(0, +) / Double(speedHistory.count)
        currentSpeed = averageSpeed

        log("位置更新: 距离=\(String(format: "%.1f", distance))m, 时间间隔=\(String(format: "%.1f", timeInterval))s, 瞬时速度=\(String(format: "%.1f", instantSpeedKmh))km/h, 平均速度=\(String(format: "%.1f", averageSpeed))km/h", level: "DEBUG")

        // 速度检测
        if averageSpeed > maxSpeedKmh {
            handleOverspeed(speed: averageSpeed)
            // 超速时不计入距离，但更新位置以便继续监测
            lastLocation = location
            lastLocationTime = location.timestamp
            return
        } else {
            // 速度正常，清除超速警告
            if isOverspeedWarning {
                clearOverspeedWarning()
            }
        }

        // 过滤条件3：距离跳变检查（可能是GPS漂移）
        if distance > maxJumpDistance {
            log("距离跳变异常: \(String(format: "%.1f", distance))m > \(maxJumpDistance)m，忽略此点", level: "WARN")
            lastLocation = location
            lastLocationTime = location.timestamp
            return
        }

        // 过滤条件4：最小移动距离（防止原地抖动）
        if distance < minMoveDistance {
            lastLocation = location
            lastLocationTime = location.timestamp
            return // 静默跳过
        }

        // 累加有效距离
        currentDistance += distance
        lastLocation = location
        lastLocationTime = location.timestamp

        // 更新奖励等级
        let newTier = RewardTier.from(distance: currentDistance)
        if newTier != currentTier {
            log("奖励等级提升: \(currentTier.displayName) -> \(newTier.displayName)")
            currentTier = newTier
        }

        log("有效移动: +\(String(format: "%.1f", distance))m, 累计距离: \(String(format: "%.0f", currentDistance))m, 速度: \(String(format: "%.1f", averageSpeed))km/h")

        // Day22+: 检查是否需要立即上报位置（移动超过50米）
        PlayerDensityManager.shared.checkMovementReport()
    }

    // MARK: - 速度检测

    /// 处理超速情况
    private func handleOverspeed(speed: Double) {
        if !isOverspeedWarning {
            // 开始超速警告
            isOverspeedWarning = true
            overspeedStartTime = Date()
            overspeedCountdown = overspeedToleranceSeconds
            log("⚠️ 检测到超速: \(String(format: "%.1f", speed))km/h > \(maxSpeedKmh)km/h，开始 \(overspeedToleranceSeconds) 秒倒计时", level: "WARN")

            // 启动超速计时器
            overspeedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateOverspeedCountdown()
                }
            }
        } else {
            log("超速持续中: \(String(format: "%.1f", speed))km/h, 剩余 \(overspeedCountdown) 秒", level: "WARN")
        }
    }

    /// 更新超速倒计时
    private func updateOverspeedCountdown() {
        guard isOverspeedWarning else { return }

        overspeedCountdown -= 1
        log("超速倒计时: \(overspeedCountdown) 秒", level: "WARN")

        if overspeedCountdown <= 0 {
            // 超速时间到，停止探索
            log("超速时间超过 \(overspeedToleranceSeconds) 秒，自动停止探索", level: "ERROR")
            Task {
                await stopExplorationDueToOverspeed()
            }
        }
    }

    /// 清除超速警告
    private func clearOverspeedWarning() {
        log("速度恢复正常，清除超速警告")
        isOverspeedWarning = false
        overspeedCountdown = 0
        overspeedStartTime = nil
        overspeedTimer?.invalidate()
        overspeedTimer = nil
    }

    /// 因超速停止探索
    private func stopExplorationDueToOverspeed() async {
        log("========== 探索因超速失败 ==========", level: "ERROR")

        // 停止所有计时器
        timer?.invalidate()
        timer = nil
        overspeedTimer?.invalidate()
        overspeedTimer = nil

        // 更新数据库状态
        if let sessionId = currentSessionId {
            do {
                try await supabase
                    .from("exploration_sessions")
                    .update(["status": "failed_overspeed"])
                    .eq("id", value: sessionId.uuidString)
                    .execute()
                log("数据库状态已更新为: failed_overspeed")
            } catch {
                log("更新数据库失败状态失败: \(error)", level: "ERROR")
            }
        }

        // 设置失败状态
        explorationFailed = true
        failureReason = .overspeed

        // Day22+ 玩家密度检测：停止位置上报
        PlayerDensityManager.shared.stopLocationReporting()

        // 重置探索状态
        isExploring = false
        isOverspeedWarning = false
        overspeedCountdown = 0
        currentSessionId = nil
        startTime = nil
        startLocation = nil
        lastLocation = nil
        lastLocationTime = nil
        overspeedStartTime = nil
        speedHistory = []
    }

    /// 结束探索
    func stopExploration() async -> ExplorationResult? {
        guard isExploring else {
            log("未在探索中，无法结束", level: "WARN")
            return nil
        }

        log("========== 结束探索 ==========")

        // 停止所有计时器
        timer?.invalidate()
        timer = nil
        overspeedTimer?.invalidate()
        overspeedTimer = nil

        // 计算最终数据
        let endTime = Date()
        let duration = Int(currentDuration)
        let distance = currentDistance
        let tier = RewardTier.from(distance: distance)
        let endLocation = LocationManager.shared.userLocation

        log("探索统计: 距离=\(String(format: "%.0f", distance))m, 时长=\(duration)秒, 等级=\(tier.displayName)")

        // 生成奖励
        let rewards = generateRewards(tier: tier)

        // 更新数据库
        if let sessionId = currentSessionId {
            do {
                let updateSession = UpdateExplorationSession(
                    endTime: ISO8601DateFormatter().string(from: endTime),
                    durationSeconds: duration,
                    totalDistance: distance,
                    rewardTier: tier.rawValue,
                    itemsRewarded: rewards.map { RewardedItemForDB(from: $0) },
                    endLat: endLocation?.latitude,
                    endLng: endLocation?.longitude,
                    status: "completed"
                )

                try await supabase
                    .from("exploration_sessions")
                    .update(updateSession)
                    .eq("id", value: sessionId.uuidString)
                    .execute()

                log("数据库更新成功: session_id=\(sessionId.uuidString)")
            } catch {
                log("数据库更新失败: \(error)", level: "ERROR")
            }

            // 存入背包
            if !rewards.isEmpty {
                await addRewardsToInventory(rewards)
            } else {
                log("无奖励物品，跳过背包存储", level: "DEBUG")
            }
        }

        // 创建结果
        let result = ExplorationResult(
            distance: distance,
            duration: duration,
            tier: tier,
            rewards: rewards,
            itemDefinitions: itemDefinitions
        )

        // 重置状态
        isExploring = false
        isOverspeedWarning = false
        overspeedCountdown = 0
        currentSessionId = nil
        startTime = nil
        startLocation = nil
        lastLocation = nil
        lastLocationTime = nil
        overspeedStartTime = nil
        speedHistory = []
        lastExplorationResult = result

        // Day22 POI搜刮：清理地理围栏和POI列表
        cleanupGeofences()

        // Day22+ 玩家密度检测：停止位置上报
        PlayerDensityManager.shared.stopLocationReporting()

        log("探索结束，状态已重置")

        return result
    }

    /// 取消探索（不保存）
    func cancelExploration() async {
        guard isExploring else {
            log("未在探索中，无法取消", level: "WARN")
            return
        }

        log("========== 取消探索 ==========")
        log("取消时已走距离: \(String(format: "%.0f", currentDistance))m, 时长: \(Int(currentDuration))秒")

        // 停止所有计时器
        timer?.invalidate()
        timer = nil
        overspeedTimer?.invalidate()
        overspeedTimer = nil

        // 更新数据库状态为取消
        if let sessionId = currentSessionId {
            do {
                try await supabase
                    .from("exploration_sessions")
                    .update(["status": "cancelled"])
                    .eq("id", value: sessionId.uuidString)
                    .execute()
                log("数据库状态已更新为: cancelled")
            } catch {
                log("更新取消状态失败: \(error)", level: "ERROR")
            }
        }

        // Day22+ 玩家密度检测：停止位置上报
        PlayerDensityManager.shared.stopLocationReporting()

        // 重置状态
        isExploring = false
        currentDistance = 0
        currentDuration = 0
        currentSpeed = 0
        currentTier = .none
        isOverspeedWarning = false
        overspeedCountdown = 0
        currentSessionId = nil
        startTime = nil
        startLocation = nil
        lastLocation = nil
        lastLocationTime = nil
        overspeedStartTime = nil
        speedHistory = []

        log("探索已取消，状态已重置")
    }

    // MARK: - 私有方法

    /// 更新探索时长
    private func updateDuration() {
        guard let start = startTime else { return }
        currentDuration = Date().timeIntervalSince(start)
    }

    /// 生成奖励物品
    private func generateRewards(tier: RewardTier) -> [RewardedItem] {
        guard tier != .none else {
            log("奖励等级为 none，无奖励物品", level: "DEBUG")
            return []
        }

        log("开始生成奖励: 等级=\(tier.displayName), 物品数=\(tier.itemCount)")

        let itemCount = tier.itemCount
        let probs = tier.rarityProbabilities

        // 按稀有度分组物品
        let commonItems = itemDefinitions.filter { $0.rarity == "common" }
        let rareItems = itemDefinitions.filter { $0.rarity == "uncommon" || $0.rarity == "rare" }
        let epicItems = itemDefinitions.filter { $0.rarity == "epic" || $0.rarity == "legendary" }

        log("物品池: 普通=\(commonItems.count), 稀有=\(rareItems.count), 史诗=\(epicItems.count)", level: "DEBUG")

        var rewards: [RewardedItem] = []

        for i in 0..<itemCount {
            let roll = Double.random(in: 0...1)
            let selectedItem: DBItemDefinition?
            var rarityType = ""

            if roll < probs.common {
                selectedItem = commonItems.randomElement()
                rarityType = "普通"
            } else if roll < probs.common + probs.rare {
                selectedItem = rareItems.randomElement() ?? commonItems.randomElement()
                rarityType = "稀有"
            } else {
                selectedItem = epicItems.randomElement() ?? rareItems.randomElement() ?? commonItems.randomElement()
                rarityType = "史诗"
            }

            if let item = selectedItem {
                // 确定品质（如果物品有品质属性）
                let quality: String? = item.hasQuality ? ["fresh", "normal", "stale"].randomElement() : nil

                let reward = RewardedItem(
                    id: UUID().uuidString,
                    itemId: item.id,
                    quantity: 1,
                    quality: quality
                )
                rewards.append(reward)
                log("奖励 #\(i+1): \(item.name) (\(rarityType), 品质: \(quality ?? "无"))", level: "DEBUG")
            }
        }

        log("成功生成 \(rewards.count) 个奖励物品")
        return rewards
    }

    /// 将奖励存入背包
    private func addRewardsToInventory(_ rewards: [RewardedItem]) async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            log("用户未登录，无法存入背包", level: "ERROR")
            return
        }

        log("开始存入背包: 共 \(rewards.count) 件物品")

        var successCount = 0
        var failCount = 0

        for (index, reward) in rewards.enumerated() {
            let itemName = itemDefinitions.first { $0.id == reward.itemId }?.name ?? reward.itemId

            let newItem = NewDBInventoryItem(
                userId: userId.uuidString,
                itemId: reward.itemId,
                quantity: reward.quantity,
                quality: reward.quality
            )

            do {
                // 直接插入新记录
                try await supabase
                    .from("inventory_items")
                    .insert(newItem)
                    .execute()

                successCount += 1
                log("[\(index+1)/\(rewards.count)] 成功存入: \(itemName) x\(reward.quantity)")
            } catch {
                failCount += 1
                log("[\(index+1)/\(rewards.count)] 存入失败: \(itemName), 错误: \(error)", level: "ERROR")
            }
        }

        log("背包存储完成: 成功=\(successCount), 失败=\(failCount)")
    }

    // MARK: - POI 搜刮方法（Day22）

    /// Day22+ 查询附近玩家密度并搜索POI
    private func queryDensityAndSearchPOIs() {
        guard isExploring else { return }

        PlayerDensityManager.shared.queryNearbyPlayersAndDensity { [weak self] count, tier in
            guard let self = self else { return }

            self.nearbyPlayerCount = count
            self.densityTier = tier

            self.log("🎯 [探索] 附近玩家: \(count)人，密度: \(tier.displayName)，建议显示 \(tier.recommendedPOICount) 个POI")

            // 带密度参数搜索POI
            self.searchNearbyPOIsWithDensity(limit: tier.recommendedPOICount)
        }
    }

    /// 带重试机制的POI搜索（最多重试3次）
    private func searchNearbyPOIsWithRetry(attemptCount: Int = 0) {
        guard isExploring else { return }
        guard attemptCount < 3 else {
            log("❌ [POI] POI搜索失败：重试3次后仍无法获取位置", level: "ERROR")
            return
        }

        guard let currentLocation = LocationManager.shared.userLocation else {
            log("⏳ [POI] 位置尚未准备好，1秒后重试... (尝试 \(attemptCount + 1)/3)", level: "WARN")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.searchNearbyPOIsWithRetry(attemptCount: attemptCount + 1)
            }
            return
        }

        // 位置已就绪，查询密度并搜索
        hasSearchedPOIs = true
        queryDensityAndSearchPOIs()
    }

    /// Day22+ 根据密度搜索附近POI
    private func searchNearbyPOIsWithDensity(limit: Int) {
        guard let currentLocation = LocationManager.shared.userLocation else {
            log("当前位置为空，跳过POI搜索", level: "WARN")
            return
        }

        log("🔍 [POI] 开始搜索附近POI，限制数量: \(limit)")

        POISearchManager.shared.searchNearbyPOIs(
            center: currentLocation,
            limit: limit
        ) { [weak self] pois in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.nearbyPOIs = pois
                self.log("🎯 [POI] 找到 \(pois.count) 个附近POI")

                // 打印找到的POI详情
                for poi in pois {
                    self.log("  - \(poi.name) (\(poi.type.displayName))", level: "DEBUG")
                }

                // 设置地理围栏
                self.setupGeofences()
            }
        }
    }

    /// 设置地理围栏
    private func setupGeofences() {
        guard nearbyPOIs.count <= 15 else {
            log("POI数量超过15个，仅监控前15个", level: "WARN")
            return
        }

        for poi in nearbyPOIs {
            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: geofenceRadius,
                identifier: poi.id
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            LocationManager.shared.startMonitoring(region: region)
            monitoredRegions[poi.id] = region

            log("监控POI: \(poi.name) (id: \(poi.id), 半径: 50m)", level: "DEBUG")
        }

        log("地理围栏设置完成，共监控 \(monitoredRegions.count) 个POI")
    }

    /// 处理进入围栏事件（LocationManager回调）
    func handleGeofenceEntry(poiId: String) {
        guard isExploring else { return }

        log("进入POI围栏: \(poiId)")

        guard let poi = nearbyPOIs.first(where: { $0.id == poiId }) else {
            log("未找到POI: \(poiId)", level: "ERROR")
            return
        }

        // 如果已搜刮，不弹窗
        if poi.hasBeenScavenged {
            log("POI已被搜刮，跳过: \(poi.name)")
            return
        }

        currentProximityPOI = poi
        showPOIPopup = true

        log("显示搜刮弹窗: \(poi.name)")
    }

    /// 搜刮POI（Day23 集成AI生成）
    func scavengePOI(_ poi: RealPOI) {
        log("开始搜刮POI: \(poi.name)")

        // 计算物品数量（1-3件随机）
        let itemCount = Int.random(in: 1...3)

        // 使用AI生成物品（Day23）
        Task { @MainActor in
            // 尝试AI生成
            let aiItems = await AIItemGenerator.shared.generateItems(
                for: poi,
                dangerLevel: poi.dangerLevel,
                count: itemCount
            )

            var loot: [LootRecord]

            if let aiItems = aiItems, !aiItems.isEmpty {
                // AI生成成功，转换为LootRecord格式
                loot = aiItems.map { aiItem in
                    LootRecord(
                        id: UUID().uuidString,
                        itemId: "ai_generated_\(UUID().uuidString)",  // AI生成物品使用特殊ID
                        quantity: 1,  // AI生成的物品默认数量为1
                        quality: nil,  // AI生成物品无品质系统
                        aiName: aiItem.name,  // AI生成的名称
                        aiCategory: aiItem.category,
                        aiRarity: aiItem.rarity,
                        aiStory: aiItem.story
                    )
                }
                log("✨ [AI] 成功生成 \(loot.count) 件AI物品")
                for item in loot {
                    log("  - \(item.displayName) [\(item.aiRarity ?? "未知")]")
                }
            } else {
                // AI生成失败，使用降级方案
                log("⚠️ [AI] 生成失败，使用备用物品生成")
                loot = ScavengeManager.shared.generateLoot()
                log("生成 \(loot.count) 件备用物品")
            }

            // 存入背包（AI生成物品暂时不存数据库，仅在搜刮结果中显示）
            // TODO: 后续可考虑将AI物品持久化到数据库
            for item in loot where !item.isAIGenerated {
                // 只有非AI物品才存入背包
                await InventoryManager.shared.addItem(itemId: item.itemId, quantity: item.quantity)
                log("添加物品到背包: \(item.displayName)")
            }

            // 标记已搜刮
            if let index = nearbyPOIs.firstIndex(where: { $0.id == poi.id }) {
                nearbyPOIs[index].hasBeenScavenged = true
                log("标记POI已搜刮: \(poi.name)")
            }

            lastScavengedItems = loot  // 保存最近搜刮的物品（用于结果展示）

            log("搜刮完成: \(poi.name)，获得 \(loot.count) 件物品")
        }
    }

    /// 停止探索时清理围栏
    private func cleanupGeofences() {
        log("清理地理围栏...", level: "INFO")

        for (_, region) in monitoredRegions {
            LocationManager.shared.stopMonitoring(region: region)
        }

        let count = monitoredRegions.count
        monitoredRegions.removeAll()
        nearbyPOIs.removeAll()
        currentProximityPOI = nil
        lastScavengedItems = nil
        hasSearchedPOIs = false  // 重置搜索标志

        log("清理完成，已停止 \(count) 个地理围栏监控")
    }

    // MARK: - 格式化方法

    /// 格式化距离
    var formattedDistance: String {
        if currentDistance < 1000 {
            return String(format: "%.0f 米", currentDistance)
        } else {
            return String(format: "%.2f 公里", currentDistance / 1000)
        }
    }

    /// 格式化时长
    var formattedDuration: String {
        let minutes = Int(currentDuration) / 60
        let seconds = Int(currentDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 探索结果

/// 探索结果数据
struct ExplorationResult {
    let distance: Double
    let duration: Int
    let tier: RewardTier
    let rewards: [RewardedItem]
    let itemDefinitions: [DBItemDefinition]

    /// 格式化距离
    var formattedDistance: String {
        if distance < 1000 {
            return String(format: "%.0f 米", distance)
        } else {
            return String(format: "%.2f 公里", distance / 1000)
        }
    }

    /// 格式化时长
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d 分 %02d 秒", minutes, seconds)
    }

    /// 获取奖励物品的定义
    func getItemDefinition(for reward: RewardedItem) -> DBItemDefinition? {
        return itemDefinitions.first { $0.id == reward.itemId }
    }
}
