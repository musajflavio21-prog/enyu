//
//  LeaderboardManager.swift
//  EarthLord
//
//  排行榜管理器
//  负责排行榜数据查询、用户排名计算、排行榜更新等
//

import Foundation
import Combine
import Supabase

/// 排行榜管理器
@MainActor
class LeaderboardManager: ObservableObject {

    // MARK: - 单例

    static let shared = LeaderboardManager()

    // MARK: - 发布属性

    /// 当前排行榜类型
    @Published var currentType: LeaderboardType = .territoryCount

    /// 当前时间范围
    @Published var currentTimeRange: LeaderboardTimeRange = .allTime

    /// 排行榜数据
    @Published var entries: [LeaderboardEntry] = []

    /// 当前用户排名信息
    @Published var myRankInfo: UserLeaderboardInfo?

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        AuthManager.shared.supabaseClient
    }

    /// 每页数据量
    private let pageSize = 50

    /// 缓存的排行榜数据
    private var cache: [String: (entries: [LeaderboardEntry], timestamp: Date)] = [:]

    /// 缓存有效时间（秒）
    private let cacheValidDuration: TimeInterval = 60

    // MARK: - 初始化

    private init() {
        print("🔄 [排行榜] LeaderboardManager 初始化")
    }

    // MARK: - 加载排行榜

    /// 加载排行榜
    /// - Parameters:
    ///   - type: 排行榜类型
    ///   - timeRange: 时间范围
    ///   - forceRefresh: 是否强制刷新（忽略缓存）
    func loadLeaderboard(
        type: LeaderboardType = .territoryCount,
        timeRange: LeaderboardTimeRange = .allTime,
        forceRefresh: Bool = false
    ) async {
        currentType = type
        currentTimeRange = timeRange

        // 检查缓存
        let cacheKey = "\(type.rawValue)_\(timeRange.rawValue)"
        if !forceRefresh,
           let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheValidDuration {
            entries = cached.entries
            print("🔄 [排行榜] 使用缓存数据: \(type.displayName)")
            await loadMyRank(type: type)
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 根据排行榜类型构建查询
            let response: [LeaderboardResponse]

            if let startDate = timeRange.startDate {
                // 带时间范围过滤
                response = try await supabase
                    .from(getTableName(for: type))
                    .select()
                    .eq("type", value: type.rawValue)
                    .gte("updated_at", value: ISO8601DateFormatter().string(from: startDate))
                    .order("value", ascending: false)
                    .limit(pageSize)
                    .execute()
                    .value
            } else {
                // 无时间范围过滤
                response = try await supabase
                    .from(getTableName(for: type))
                    .select()
                    .eq("type", value: type.rawValue)
                    .order("value", ascending: false)
                    .limit(pageSize)
                    .execute()
                    .value
            }

            // 转换为带排名的条目
            entries = response.enumerated().map { index, item in
                LeaderboardEntry(
                    id: UUID(),
                    userId: item.userId,
                    username: item.username,
                    value: item.value,
                    rank: index + 1,
                    updatedAt: Date()
                )
            }

            // 更新缓存
            cache[cacheKey] = (entries, Date())

            print("🔄 [排行榜] 加载了 \(entries.count) 条 \(type.displayName) 数据")

            // 加载当前用户排名
            await loadMyRank(type: type)

        } catch {
            print("❌ [排行榜] 加载失败: \(error)")
            errorMessage = "加载排行榜失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 获取表名
    private func getTableName(for type: LeaderboardType) -> String {
        // 使用统一的排行榜表，通过 type 字段区分
        return "leaderboards"
    }

    /// 加载当前用户排名
    private func loadMyRank(type: LeaderboardType) async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            myRankInfo = nil
            return
        }

        do {
            // 查询用户在该排行榜的数据
            let userEntries: [LeaderboardResponse] = try await supabase
                .from(getTableName(for: type))
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("type", value: type.rawValue)
                .execute()
                .value

            if let userEntry = userEntries.first {
                // 计算排名
                let higherCount: Int = try await supabase
                    .from(getTableName(for: type))
                    .select("*", head: true, count: .exact)
                    .eq("type", value: type.rawValue)
                    .gt("value", value: userEntry.value)
                    .execute()
                    .count ?? 0

                let totalCount: Int = try await supabase
                    .from(getTableName(for: type))
                    .select("*", head: true, count: .exact)
                    .eq("type", value: type.rawValue)
                    .execute()
                    .count ?? 0

                myRankInfo = UserLeaderboardInfo(
                    type: type,
                    rank: higherCount + 1,
                    value: userEntry.value,
                    totalPlayers: totalCount
                )
            } else {
                myRankInfo = UserLeaderboardInfo(
                    type: type,
                    rank: nil,
                    value: 0,
                    totalPlayers: entries.count
                )
            }

        } catch {
            print("⚠️ [排行榜] 加载用户排名失败: \(error)")
            myRankInfo = nil
        }
    }

    // MARK: - 更新排行榜

    /// 更新用户排行榜数值
    /// - Parameters:
    ///   - type: 排行榜类型
    ///   - value: 新数值
    func updateValue(type: LeaderboardType, value: Int) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        let username = AuthManager.shared.currentUser?.email?.components(separatedBy: "@").first ?? "匿名"

        do {
            // 使用 upsert 更新或插入
            let upsertData = LeaderboardUpsert(
                userId: userId.uuidString,
                username: username,
                type: type.rawValue,
                value: value,
                updatedAt: Date()
            )

            try await supabase
                .from(getTableName(for: type))
                .upsert(upsertData)
                .execute()

            print("✅ [排行榜] 更新 \(type.displayName): \(value)")

            // 清除缓存
            invalidateCache(for: type)

        } catch {
            print("⚠️ [排行榜] 更新失败: \(error)")
        }
    }

    /// 增量更新排行榜数值
    /// - Parameters:
    ///   - type: 排行榜类型
    ///   - increment: 增量
    func incrementValue(type: LeaderboardType, by increment: Int) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        let username = AuthManager.shared.currentUser?.email?.components(separatedBy: "@").first ?? "匿名"

        do {
            // 先查询当前值
            let existing: [LeaderboardResponse] = try await supabase
                .from(getTableName(for: type))
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("type", value: type.rawValue)
                .execute()
                .value

            let currentValue = existing.first?.value ?? 0
            let newValue = currentValue + increment

            // 更新
            let upsertData = LeaderboardUpsert(
                userId: userId.uuidString,
                username: username,
                type: type.rawValue,
                value: newValue,
                updatedAt: Date()
            )

            try await supabase
                .from(getTableName(for: type))
                .upsert(upsertData)
                .execute()

            print("✅ [排行榜] 增量更新 \(type.displayName): +\(increment) = \(newValue)")

            // 清除缓存
            invalidateCache(for: type)

        } catch {
            print("⚠️ [排行榜] 增量更新失败: \(error)")
        }
    }

    // MARK: - 缓存管理

    /// 清除指定类型的缓存
    func invalidateCache(for type: LeaderboardType) {
        for timeRange in LeaderboardTimeRange.allCases {
            let key = "\(type.rawValue)_\(timeRange.rawValue)"
            cache.removeValue(forKey: key)
        }
    }

    /// 清除所有缓存
    func clearAllCache() {
        cache.removeAll()
    }

    // MARK: - 切换类型

    /// 切换排行榜类型
    func switchType(_ type: LeaderboardType) async {
        guard type != currentType else { return }
        await loadLeaderboard(type: type, timeRange: currentTimeRange)
    }

    /// 切换时间范围
    func switchTimeRange(_ timeRange: LeaderboardTimeRange) async {
        guard timeRange != currentTimeRange else { return }
        await loadLeaderboard(type: currentType, timeRange: timeRange)
    }

    // MARK: - 刷新

    /// 强制刷新当前排行榜
    func refresh() async {
        await loadLeaderboard(type: currentType, timeRange: currentTimeRange, forceRefresh: true)
    }

    // MARK: - 辅助方法

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 检查用户是否在榜上
    func isUserOnBoard() -> Bool {
        guard let userId = AuthManager.shared.currentUser?.id else { return false }
        return entries.contains { $0.userId == userId }
    }

    /// 获取用户在当前榜单的条目
    func getUserEntry() -> LeaderboardEntry? {
        guard let userId = AuthManager.shared.currentUser?.id else { return nil }
        return entries.first { $0.userId == userId }
    }
}
