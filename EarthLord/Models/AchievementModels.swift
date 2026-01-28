//
//  AchievementModels.swift
//  EarthLord
//
//  成就系统数据模型
//  定义成就类型、条件、奖励等
//

import Foundation

// MARK: - 成就类别

/// 成就类别枚举
enum AchievementCategory: String, Codable, CaseIterable {
    case territory = "territory"        // 领地相关
    case exploration = "exploration"    // 探索相关
    case trade = "trade"                // 交易相关
    case building = "building"          // 建造相关
    case survival = "survival"          // 生存相关
    case social = "social"              // 社交相关

    /// 类别显示名称
    var displayName: String {
        switch self {
        case .territory: return "领地征服"
        case .exploration: return "废土探索"
        case .trade: return "交易大师"
        case .building: return "建造专家"
        case .survival: return "末日生存"
        case .social: return "社交达人"
        }
    }

    /// 类别图标
    var iconName: String {
        switch self {
        case .territory: return "flag.fill"
        case .exploration: return "map.fill"
        case .trade: return "cart.fill"
        case .building: return "building.2.fill"
        case .survival: return "heart.fill"
        case .social: return "person.3.fill"
        }
    }
}

// MARK: - 成就稀有度

/// 成就稀有度枚举
enum AchievementRarity: String, Codable, CaseIterable {
    case common = "common"              // 普通
    case uncommon = "uncommon"          // 稀有
    case rare = "rare"                  // 珍贵
    case epic = "epic"                  // 史诗
    case legendary = "legendary"        // 传说

    /// 稀有度显示名称
    var displayName: String {
        switch self {
        case .common: return "普通"
        case .uncommon: return "稀有"
        case .rare: return "珍贵"
        case .epic: return "史诗"
        case .legendary: return "传说"
        }
    }

    /// 稀有度颜色名称
    var colorName: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }

    /// 经验奖励倍数
    var expMultiplier: Double {
        switch self {
        case .common: return 1.0
        case .uncommon: return 1.5
        case .rare: return 2.0
        case .epic: return 3.0
        case .legendary: return 5.0
        }
    }
}

// MARK: - 成就定义

/// 成就定义结构体（静态数据）
struct AchievementDefinition: Codable, Identifiable {
    let id: String                          // 成就唯一标识
    let name: String                        // 成就名称
    let description: String                 // 成就描述
    let category: AchievementCategory       // 成就类别
    let rarity: AchievementRarity           // 成就稀有度
    let iconName: String                    // 图标名称
    let targetValue: Int                    // 目标数值
    let expReward: Int                      // 经验奖励
    let itemRewards: [AchievementItemReward]?  // 物品奖励

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case category
        case rarity
        case iconName = "icon_name"
        case targetValue = "target_value"
        case expReward = "exp_reward"
        case itemRewards = "item_rewards"
    }
}

/// 成就物品奖励
struct AchievementItemReward: Codable {
    let itemId: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
    }
}

// MARK: - 用户成就进度

/// 用户成就进度
struct UserAchievement: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let achievementId: String
    let currentValue: Int
    let isCompleted: Bool
    let completedAt: Date?
    let rewardClaimed: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case achievementId = "achievement_id"
        case currentValue = "current_value"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
        case rewardClaimed = "reward_claimed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 计算进度百分比
    func progressPercentage(targetValue: Int) -> Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, Double(currentValue) / Double(targetValue))
    }
}

// MARK: - 成就进度更新

/// 成就进度更新
struct AchievementProgressUpdate: Codable {
    let currentValue: Int
    let isCompleted: Bool
    let completedAt: Date?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case currentValue = "current_value"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
        case updatedAt = "updated_at"
    }
}

/// 领取奖励更新
struct AchievementRewardClaimUpdate: Codable {
    let rewardClaimed: Bool

    enum CodingKeys: String, CodingKey {
        case rewardClaimed = "reward_claimed"
    }
}

// MARK: - 新建用户成就

/// 新建用户成就记录
struct NewUserAchievement: Codable {
    let userId: String
    let achievementId: String
    let currentValue: Int
    let isCompleted: Bool
    let rewardClaimed: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case achievementId = "achievement_id"
        case currentValue = "current_value"
        case isCompleted = "is_completed"
        case rewardClaimed = "reward_claimed"
    }
}

// MARK: - 成就触发事件

/// 成就触发事件类型
enum AchievementTrigger {
    case territoryCreated                   // 创建领地
    case territoryClaimed(area: Double)     // 圈占领地面积
    case poiExplored                        // 探索POI
    case itemScavenged(count: Int)          // 搜刮物品
    case tradeCompleted                     // 完成交易
    case tradeVolume(amount: Int)           // 交易金额
    case buildingConstructed                // 建造建筑
    case buildingUpgraded                   // 升级建筑
    case playersMet(count: Int)             // 遇到玩家
    case messagesSent(count: Int)           // 发送消息
    case daysPlayed(count: Int)             // 游戏天数
    case distanceWalked(meters: Double)     // 行走距离

    /// 获取对应的成就ID前缀
    var achievementIdPrefix: String {
        switch self {
        case .territoryCreated: return "territory_create"
        case .territoryClaimed: return "territory_area"
        case .poiExplored: return "exploration_poi"
        case .itemScavenged: return "exploration_scavenge"
        case .tradeCompleted: return "trade_complete"
        case .tradeVolume: return "trade_volume"
        case .buildingConstructed: return "building_construct"
        case .buildingUpgraded: return "building_upgrade"
        case .playersMet: return "social_meet"
        case .messagesSent: return "social_message"
        case .daysPlayed: return "survival_days"
        case .distanceWalked: return "survival_distance"
        }
    }

    /// 获取增量值
    var incrementValue: Int {
        switch self {
        case .territoryCreated: return 1
        case .territoryClaimed(let area): return Int(area)
        case .poiExplored: return 1
        case .itemScavenged(let count): return count
        case .tradeCompleted: return 1
        case .tradeVolume(let amount): return amount
        case .buildingConstructed: return 1
        case .buildingUpgraded: return 1
        case .playersMet(let count): return count
        case .messagesSent(let count): return count
        case .daysPlayed(let count): return count
        case .distanceWalked(let meters): return Int(meters)
        }
    }
}

// MARK: - 成就错误

/// 成就错误枚举
enum AchievementError: Error, LocalizedError {
    case notLoggedIn                        // 未登录
    case achievementNotFound                // 找不到成就
    case alreadyCompleted                   // 已完成
    case alreadyClaimed                     // 已领取
    case notCompleted                       // 未完成（无法领取）
    case databaseError(String)              // 数据库错误
    case unknown(String)                    // 未知错误

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "请先登录"
        case .achievementNotFound:
            return "找不到该成就"
        case .alreadyCompleted:
            return "成就已完成"
        case .alreadyClaimed:
            return "奖励已领取"
        case .notCompleted:
            return "成就未完成，无法领取奖励"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}

// MARK: - 预定义成就列表

/// 预定义成就列表
let predefinedAchievements: [AchievementDefinition] = [
    // 领地成就
    AchievementDefinition(
        id: "territory_create_1",
        name: "初露锋芒",
        description: "创建第一块领地",
        category: .territory,
        rarity: .common,
        iconName: "flag.fill",
        targetValue: 1,
        expReward: 100,
        itemRewards: nil
    ),
    AchievementDefinition(
        id: "territory_create_10",
        name: "领地开拓者",
        description: "创建10块领地",
        category: .territory,
        rarity: .uncommon,
        iconName: "flag.2.crossed.fill",
        targetValue: 10,
        expReward: 500,
        itemRewards: nil
    ),
    AchievementDefinition(
        id: "territory_create_50",
        name: "领地霸主",
        description: "创建50块领地",
        category: .territory,
        rarity: .rare,
        iconName: "crown.fill",
        targetValue: 50,
        expReward: 2000,
        itemRewards: nil
    ),
    AchievementDefinition(
        id: "territory_area_1000",
        name: "小有规模",
        description: "累计圈占1000平方米领地",
        category: .territory,
        rarity: .common,
        iconName: "square.grid.3x3.fill",
        targetValue: 1000,
        expReward: 200,
        itemRewards: nil
    ),

    // 探索成就
    AchievementDefinition(
        id: "exploration_poi_10",
        name: "废土探险家",
        description: "探索10个兴趣点",
        category: .exploration,
        rarity: .common,
        iconName: "binoculars.fill",
        targetValue: 10,
        expReward: 150,
        itemRewards: nil
    ),
    AchievementDefinition(
        id: "exploration_poi_100",
        name: "地图专家",
        description: "探索100个兴趣点",
        category: .exploration,
        rarity: .rare,
        iconName: "map.fill",
        targetValue: 100,
        expReward: 1500,
        itemRewards: nil
    ),
    AchievementDefinition(
        id: "exploration_scavenge_100",
        name: "拾荒者",
        description: "搜刮100件物品",
        category: .exploration,
        rarity: .uncommon,
        iconName: "archivebox.fill",
        targetValue: 100,
        expReward: 300,
        itemRewards: nil
    ),

    // 交易成就
    AchievementDefinition(
        id: "trade_complete_1",
        name: "初次交易",
        description: "完成第一次交易",
        category: .trade,
        rarity: .common,
        iconName: "cart.fill",
        targetValue: 1,
        expReward: 100,
        itemRewards: nil
    ),
    AchievementDefinition(
        id: "trade_complete_50",
        name: "交易高手",
        description: "完成50次交易",
        category: .trade,
        rarity: .rare,
        iconName: "cart.badge.plus",
        targetValue: 50,
        expReward: 1000,
        itemRewards: nil
    ),

    // 建造成就
    AchievementDefinition(
        id: "building_construct_1",
        name: "建造新手",
        description: "建造第一个建筑",
        category: .building,
        rarity: .common,
        iconName: "house.fill",
        targetValue: 1,
        expReward: 100,
        itemRewards: nil
    ),
    AchievementDefinition(
        id: "building_construct_20",
        name: "建筑师",
        description: "建造20个建筑",
        category: .building,
        rarity: .uncommon,
        iconName: "building.2.fill",
        targetValue: 20,
        expReward: 800,
        itemRewards: nil
    ),

    // 社交成就
    AchievementDefinition(
        id: "social_message_100",
        name: "话痨",
        description: "发送100条消息",
        category: .social,
        rarity: .uncommon,
        iconName: "bubble.left.and.bubble.right.fill",
        targetValue: 100,
        expReward: 300,
        itemRewards: nil
    ),
    AchievementDefinition(
        id: "social_meet_10",
        name: "社交达人",
        description: "遇到10个不同的玩家",
        category: .social,
        rarity: .uncommon,
        iconName: "person.3.fill",
        targetValue: 10,
        expReward: 400,
        itemRewards: nil
    ),

    // 生存成就
    AchievementDefinition(
        id: "survival_days_7",
        name: "生存一周",
        description: "连续游戏7天",
        category: .survival,
        rarity: .common,
        iconName: "calendar",
        targetValue: 7,
        expReward: 200,
        itemRewards: nil
    ),
    AchievementDefinition(
        id: "survival_days_30",
        name: "末日幸存者",
        description: "连续游戏30天",
        category: .survival,
        rarity: .rare,
        iconName: "calendar.badge.clock",
        targetValue: 30,
        expReward: 1000,
        itemRewards: nil
    ),
    AchievementDefinition(
        id: "survival_distance_10000",
        name: "行者",
        description: "累计行走10公里",
        category: .survival,
        rarity: .uncommon,
        iconName: "figure.walk",
        targetValue: 10000,
        expReward: 500,
        itemRewards: nil
    )
]
