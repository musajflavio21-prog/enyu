//
//  LeaderboardModels.swift
//  EarthLord
//
//  排行榜数据模型
//  定义排行榜类型、排名条目等
//

import Foundation

// MARK: - 排行榜类型

/// 排行榜类型枚举
enum LeaderboardType: String, Codable, CaseIterable {
    case territoryCount = "territory_count"     // 领地数量
    case territoryArea = "territory_area"       // 领地面积
    case tradeVolume = "trade_volume"           // 交易量
    case tradeCount = "trade_count"             // 交易次数
    case buildingCount = "building_count"       // 建筑数量
    case achievementCount = "achievement_count" // 成就数量
    case explorationCount = "exploration_count" // 探索POI数量

    /// 排行榜显示名称
    var displayName: String {
        switch self {
        case .territoryCount: return "领地数量"
        case .territoryArea: return "领地面积"
        case .tradeVolume: return "交易额"
        case .tradeCount: return "交易次数"
        case .buildingCount: return "建筑数量"
        case .achievementCount: return "成就数量"
        case .explorationCount: return "探索数量"
        }
    }

    /// 排行榜图标
    var iconName: String {
        switch self {
        case .territoryCount: return "flag.fill"
        case .territoryArea: return "square.grid.3x3.fill"
        case .tradeVolume: return "dollarsign.circle.fill"
        case .tradeCount: return "cart.fill"
        case .buildingCount: return "building.2.fill"
        case .achievementCount: return "trophy.fill"
        case .explorationCount: return "binoculars.fill"
        }
    }

    /// 数值单位
    var unit: String {
        switch self {
        case .territoryCount: return "块"
        case .territoryArea: return "m²"
        case .tradeVolume: return ""
        case .tradeCount: return "次"
        case .buildingCount: return "个"
        case .achievementCount: return "个"
        case .explorationCount: return "个"
        }
    }

    /// 数据库表名
    var tableName: String {
        return "leaderboard_\(self.rawValue)"
    }

    /// 数据库视图名（用于聚合查询）
    var viewName: String {
        return "v_leaderboard_\(self.rawValue)"
    }
}

// MARK: - 时间范围

/// 排行榜时间范围
enum LeaderboardTimeRange: String, Codable, CaseIterable {
    case daily = "daily"        // 日榜
    case weekly = "weekly"      // 周榜
    case monthly = "monthly"    // 月榜
    case allTime = "all_time"   // 总榜

    /// 显示名称
    var displayName: String {
        switch self {
        case .daily: return "今日"
        case .weekly: return "本周"
        case .monthly: return "本月"
        case .allTime: return "总榜"
        }
    }

    /// 获取起始时间
    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .daily:
            return calendar.startOfDay(for: now)
        case .weekly:
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
        case .monthly:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now))
        case .allTime:
            return nil
        }
    }
}

// MARK: - 排行榜条目

/// 排行榜条目
struct LeaderboardEntry: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let username: String?
    let value: Int
    let rank: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case value
        case rank
        case updatedAt = "updated_at"
    }

    /// 格式化数值
    func formattedValue(for type: LeaderboardType) -> String {
        switch type {
        case .territoryArea:
            if value >= 1000000 {
                return String(format: "%.1fkm²", Double(value) / 1000000)
            } else if value >= 10000 {
                return String(format: "%.1f万m²", Double(value) / 10000)
            } else {
                return "\(value)m²"
            }
        case .tradeVolume:
            if value >= 10000 {
                return String(format: "%.1f万", Double(value) / 10000)
            } else {
                return "\(value)"
            }
        default:
            return "\(value)\(type.unit)"
        }
    }

    /// 排名颜色
    var rankColorName: String {
        switch rank {
        case 1: return "gold"
        case 2: return "silver"
        case 3: return "bronze"
        default: return "gray"
        }
    }

    /// 排名图标
    var rankIcon: String? {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return nil
        }
    }
}

// MARK: - 排行榜数据响应

/// 排行榜数据响应（从数据库查询，不含 rank）
struct LeaderboardResponse: Codable {
    let userId: UUID
    let username: String?
    let value: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case value
    }
}

// MARK: - 用户排行信息

/// 用户在各排行榜的信息
struct UserLeaderboardInfo: Codable {
    let type: LeaderboardType
    let rank: Int?
    let value: Int
    let totalPlayers: Int

    /// 百分比排名（前 x%）
    var percentileRank: Double? {
        guard let rank = rank, totalPlayers > 0 else { return nil }
        return Double(rank) / Double(totalPlayers) * 100
    }

    /// 格式化百分比排名
    var formattedPercentile: String? {
        guard let percentile = percentileRank else { return nil }
        if percentile <= 1 {
            return "前 1%"
        } else if percentile <= 10 {
            return "前 10%"
        } else if percentile <= 50 {
            return "前 50%"
        } else {
            return nil
        }
    }
}

// MARK: - 排行榜更新请求

/// 更新排行榜数值
struct LeaderboardUpdateRequest: Codable {
    let userId: String
    let username: String?
    let value: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case value
        case updatedAt = "updated_at"
    }
}

/// 增量更新排行榜
struct LeaderboardIncrementRequest: Codable {
    let userId: String
    let increment: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case increment
    }
}

/// 排行榜 Upsert 请求
struct LeaderboardUpsert: Codable {
    let userId: String
    let username: String
    let type: String
    let value: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case type
        case value
        case updatedAt = "updated_at"
    }
}

// MARK: - 排行榜错误

/// 排行榜错误枚举
enum LeaderboardError: Error, LocalizedError {
    case notLoggedIn                        // 未登录
    case invalidType                        // 无效的排行榜类型
    case networkError(String)               // 网络错误
    case databaseError(String)              // 数据库错误
    case unknown(String)                    // 未知错误

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "请先登录"
        case .invalidType:
            return "无效的排行榜类型"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}
