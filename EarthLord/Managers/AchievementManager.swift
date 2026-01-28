//
//  AchievementManager.swift
//  EarthLord
//
//  成就管理器
//  负责成就进度追踪、成就解锁、奖励发放等
//

import Foundation
import Combine
import Supabase

/// 成就管理器
@MainActor
class AchievementManager: ObservableObject {

    // MARK: - 单例

    static let shared = AchievementManager()

    // MARK: - 发布属性

    /// 所有成就定义
    @Published var achievements: [AchievementDefinition] = predefinedAchievements

    /// 用户成就进度
    @Published var userAchievements: [UserAchievement] = []

    /// 最近解锁的成就（用于显示通知）
    @Published var recentlyUnlocked: AchievementDefinition?

    /// 未领取奖励的成就数量
    @Published var unclaimedCount: Int = 0

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        AuthManager.shared.supabaseClient
    }

    /// 成就定义字典（快速查找）
    private var achievementDict: [String: AchievementDefinition] = [:]

    // MARK: - 初始化

    private init() {
        print("🔄 [成就] AchievementManager 初始化")

        // 构建成就字典
        for achievement in achievements {
            achievementDict[achievement.id] = achievement
        }
    }

    // MARK: - 加载数据

    /// 加载用户成就进度
    func loadUserAchievements() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "请先登录"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let progress: [UserAchievement] = try await supabase
                .from("user_achievements")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            userAchievements = progress

            // 计算未领取奖励数量
            unclaimedCount = progress.filter { $0.isCompleted && !$0.rewardClaimed }.count

            print("🔄 [成就] 加载了 \(progress.count) 个成就进度")

        } catch {
            print("❌ [成就] 加载用户成就失败: \(error)")
            errorMessage = "加载成就失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 成就进度更新

    /// 触发成就事件
    /// - Parameter trigger: 成就触发事件
    func trigger(_ trigger: AchievementTrigger) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        let prefix = trigger.achievementIdPrefix
        let increment = trigger.incrementValue

        // 查找所有匹配前缀的成就
        let matchingAchievements = achievements.filter { $0.id.hasPrefix(prefix) }

        for achievement in matchingAchievements {
            await updateProgress(
                userId: userId,
                achievementId: achievement.id,
                increment: increment,
                targetValue: achievement.targetValue
            )
        }
    }

    /// 更新成就进度
    private func updateProgress(
        userId: UUID,
        achievementId: String,
        increment: Int,
        targetValue: Int
    ) async {
        do {
            // 查找现有进度
            let existing: [UserAchievement] = try await supabase
                .from("user_achievements")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("achievement_id", value: achievementId)
                .execute()
                .value

            if let progress = existing.first {
                // 已有进度，更新
                if progress.isCompleted {
                    // 已完成，跳过
                    return
                }

                let newValue = progress.currentValue + increment
                let isNowCompleted = newValue >= targetValue

                let update = AchievementProgressUpdate(
                    currentValue: newValue,
                    isCompleted: isNowCompleted,
                    completedAt: isNowCompleted ? Date() : nil,
                    updatedAt: Date()
                )

                try await supabase
                    .from("user_achievements")
                    .update(update)
                    .eq("id", value: progress.id.uuidString)
                    .execute()

                // 如果刚完成，显示通知
                if isNowCompleted {
                    if let achievement = achievementDict[achievementId] {
                        recentlyUnlocked = achievement
                        unclaimedCount += 1
                        print("🏆 [成就] 解锁成就: \(achievement.name)")
                    }
                }

            } else {
                // 新进度
                let isNowCompleted = increment >= targetValue

                let newProgress = NewUserAchievement(
                    userId: userId.uuidString,
                    achievementId: achievementId,
                    currentValue: increment,
                    isCompleted: isNowCompleted,
                    rewardClaimed: false
                )

                try await supabase
                    .from("user_achievements")
                    .insert(newProgress)
                    .execute()

                // 如果首次就完成
                if isNowCompleted {
                    if let achievement = achievementDict[achievementId] {
                        recentlyUnlocked = achievement
                        unclaimedCount += 1
                        print("🏆 [成就] 解锁成就: \(achievement.name)")
                    }
                }
            }

            // 刷新本地数据
            await loadUserAchievements()

        } catch {
            print("⚠️ [成就] 更新进度失败: \(error)")
        }
    }

    // MARK: - 领取奖励

    /// 领取成就奖励
    /// - Parameter achievementId: 成就ID
    /// - Returns: 领取结果
    func claimReward(achievementId: String) async -> Result<AchievementDefinition, Error> {
        guard let userId = AuthManager.shared.currentUser?.id else {
            return .failure(AchievementError.notLoggedIn)
        }

        // 查找成就定义
        guard let achievement = achievementDict[achievementId] else {
            return .failure(AchievementError.achievementNotFound)
        }

        do {
            // 查找用户进度
            let existing: [UserAchievement] = try await supabase
                .from("user_achievements")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("achievement_id", value: achievementId)
                .execute()
                .value

            guard let progress = existing.first else {
                return .failure(AchievementError.achievementNotFound)
            }

            // 检查是否已完成
            guard progress.isCompleted else {
                return .failure(AchievementError.notCompleted)
            }

            // 检查是否已领取
            guard !progress.rewardClaimed else {
                return .failure(AchievementError.alreadyClaimed)
            }

            // 更新为已领取
            try await supabase
                .from("user_achievements")
                .update(AchievementRewardClaimUpdate(rewardClaimed: true))
                .eq("id", value: progress.id.uuidString)
                .execute()

            // 发放物品奖励
            if let itemRewards = achievement.itemRewards {
                for reward in itemRewards {
                    _ = await InventoryManager.shared.addItemForTrade(
                        itemId: reward.itemId,
                        quantity: reward.quantity
                    )
                }
            }

            // TODO: 发放经验奖励（需要经验系统支持）

            print("✅ [成就] 领取奖励成功: \(achievement.name)")

            // 刷新数据
            await loadUserAchievements()

            return .success(achievement)

        } catch {
            print("❌ [成就] 领取奖励失败: \(error)")
            return .failure(AchievementError.databaseError(error.localizedDescription))
        }
    }

    // MARK: - 查询方法

    /// 获取成就进度
    /// - Parameter achievementId: 成就ID
    /// - Returns: 用户成就进度
    func getProgress(for achievementId: String) -> UserAchievement? {
        return userAchievements.first { $0.achievementId == achievementId }
    }

    /// 获取成就定义
    /// - Parameter achievementId: 成就ID
    /// - Returns: 成就定义
    func getAchievement(_ achievementId: String) -> AchievementDefinition? {
        return achievementDict[achievementId]
    }

    /// 获取按类别分组的成就
    /// - Returns: 按类别分组的成就字典
    func getAchievementsByCategory() -> [AchievementCategory: [AchievementDefinition]] {
        var result: [AchievementCategory: [AchievementDefinition]] = [:]

        for category in AchievementCategory.allCases {
            result[category] = achievements.filter { $0.category == category }
        }

        return result
    }

    /// 获取已完成的成就数量
    func completedCount() -> Int {
        return userAchievements.filter { $0.isCompleted }.count
    }

    /// 获取完成进度百分比
    func overallProgress() -> Double {
        guard !achievements.isEmpty else { return 0 }
        return Double(completedCount()) / Double(achievements.count)
    }

    // MARK: - 辅助方法

    /// 清除最近解锁通知
    func clearRecentlyUnlocked() {
        recentlyUnlocked = nil
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }
}
