//
//  BuildingModels.swift
//  EarthLord
//
//  建造系统数据模型
//  定义建筑分类、状态、模板和玩家建筑
//

import Foundation
import CoreLocation

// MARK: - 建筑分类

/// 建筑分类枚举
enum BuildingCategory: String, Codable, CaseIterable {
    case survival = "survival"       // 生存类（篝火、庇护所）
    case storage = "storage"         // 储存类（小仓库、中仓库）
    case production = "production"   // 生产类（简易农田、工作台）
    case energy = "energy"           // 能源类（太阳能板、风力发电机）

    /// 分类显示名称
    var displayName: String {
        switch self {
        case .survival: return "生存"
        case .storage: return "储存"
        case .production: return "生产"
        case .energy: return "能源"
        }
    }

    /// 分类图标（SF Symbol）
    var iconName: String {
        switch self {
        case .survival: return "house.fill"
        case .storage: return "archivebox.fill"
        case .production: return "hammer.fill"
        case .energy: return "bolt.fill"
        }
    }
}

// MARK: - 建筑状态

/// 建筑状态枚举
enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case active = "active"              // 运行中

    /// 状态显示名称
    var displayName: String {
        switch self {
        case .constructing: return "建造中"
        case .active: return "运行中"
        }
    }

    /// 状态颜色标识
    var colorName: String {
        switch self {
        case .constructing: return "blue"
        case .active: return "green"
        }
    }
}

// MARK: - 建筑模板

/// 建筑模板结构体（从 JSON 加载）
struct BuildingTemplate: Codable, Identifiable {
    let id: String                          // 模板 ID（如 "campfire"）
    let name: String                        // 建筑名称
    let description: String                 // 建筑描述
    let category: BuildingCategory          // 建筑分类
    let tier: Int                           // 等级层级（1-5）
    let maxLevel: Int                       // 最大升级等级
    let buildTimeSeconds: Int               // 建造时间（秒）
    let requiredResources: [String: Int]    // 所需资源 {"wood": 30, "stone": 20}
    let maxPerTerritory: Int                // 每个领地最大数量
    let iconName: String                    // 图标名称（SF Symbol）
    let effect: BuildingEffect?             // 建筑效果（可选）

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case category
        case tier
        case maxLevel = "max_level"
        case buildTimeSeconds = "build_time_seconds"
        case requiredResources = "required_resources"
        case maxPerTerritory = "max_per_territory"
        case iconName = "icon_name"
        case effect
    }

    /// 格式化建造时间
    var formattedBuildTime: String {
        if buildTimeSeconds >= 3600 {
            let hours = buildTimeSeconds / 3600
            let minutes = (buildTimeSeconds % 3600) / 60
            return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
        } else if buildTimeSeconds >= 60 {
            let minutes = buildTimeSeconds / 60
            let seconds = buildTimeSeconds % 60
            return seconds > 0 ? "\(minutes)分\(seconds)秒" : "\(minutes)分钟"
        } else {
            return "\(buildTimeSeconds)秒"
        }
    }

    /// 资源需求描述
    var resourcesDescription: String {
        requiredResources.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}

/// 建筑效果（预留扩展）
struct BuildingEffect: Codable {
    let type: String                // 效果类型（如 "storage_capacity", "production_rate"）
    let value: Double               // 效果数值
    let unit: String?               // 单位（可选）
}

// MARK: - 玩家建筑

/// 玩家已建造的建筑（存储在数据库）
struct PlayerBuilding: Codable, Identifiable {
    let id: UUID                            // 建筑记录 ID
    let userId: UUID                        // 所属玩家 ID
    let territoryId: String                 // 所属领地 ID
    let templateId: String                  // 建筑模板 ID
    let buildingName: String                // 建筑名称
    var status: BuildingStatus              // 当前状态
    var level: Int                          // 当前等级
    let locationLat: Double?                // 位置纬度（可选）
    let locationLon: Double?                // 位置经度（可选）
    let buildStartedAt: Date                // 建造开始时间
    var buildCompletedAt: Date?             // 建造完成时间
    let createdAt: Date                     // 创建时间
    var updatedAt: Date?                    // 更新时间

    // MARK: - 计算属性

    /// 建筑坐标（如果有位置信息）
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = locationLat, let lon = locationLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// 建造进度（0.0 ~ 1.0）
    func buildProgress(template: BuildingTemplate) -> Double {
        guard status == .constructing else { return 1.0 }
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        let total = Double(template.buildTimeSeconds)
        return min(1.0, max(0.0, elapsed / total))
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 检查建造是否已完成（基于时间）
    func isConstructionComplete(template: BuildingTemplate) -> Bool {
        let elapsedTime = Date().timeIntervalSince(buildStartedAt)
        return elapsedTime >= Double(template.buildTimeSeconds)
    }

    /// 获取建造剩余时间（秒）
    func remainingBuildTime(template: BuildingTemplate) -> TimeInterval {
        let elapsedTime = Date().timeIntervalSince(buildStartedAt)
        let remaining = Double(template.buildTimeSeconds) - elapsedTime
        return max(0, remaining)
    }

    /// 格式化剩余时间
    func formattedRemainingTime(template: BuildingTemplate) -> String {
        let remaining = Int(remainingBuildTime(template: template))
        if remaining <= 0 { return "完成" }

        if remaining >= 3600 {
            let hours = remaining / 3600
            let minutes = (remaining % 3600) / 60
            return "\(hours):\(String(format: "%02d", minutes)):00"
        } else if remaining >= 60 {
            let minutes = remaining / 60
            let seconds = remaining % 60
            return "\(minutes):\(String(format: "%02d", seconds))"
        } else {
            return "\(remaining)秒"
        }
    }
}

/// 新建建筑请求（用于插入数据库）
struct NewPlayerBuilding: Codable {
    let userId: String
    let territoryId: String
    let templateId: String
    let buildingName: String
    let status: String
    let level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
    }
}

// MARK: - 更新辅助结构体

/// 完成建造更新
struct BuildingStatusUpdate: Codable {
    let status: String
    let buildCompletedAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case buildCompletedAt = "build_completed_at"
        case updatedAt = "updated_at"
    }
}

/// 升级建筑更新
struct BuildingLevelUpdate: Codable {
    let level: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case level
        case updatedAt = "updated_at"
    }
}

// MARK: - 建造错误

/// 建造错误枚举
enum BuildingError: Error, LocalizedError {
    case templateNotFound               // 找不到建筑模板
    case insufficientResources          // 资源不足
    case maxBuildingsReached            // 达到数量上限
    case invalidStatus                  // 无效状态（如尝试升级建造中的建筑）
    case buildingNotFound               // 找不到建筑记录
    case notLoggedIn                    // 未登录
    case databaseError(String)          // 数据库错误
    case unknown(String)                // 未知错误

    var errorDescription: String? {
        switch self {
        case .templateNotFound:
            return "找不到建筑模板"
        case .insufficientResources:
            return "资源不足，无法建造"
        case .maxBuildingsReached:
            return "该建筑已达到数量上限"
        case .invalidStatus:
            return "当前状态不允许此操作"
        case .buildingNotFound:
            return "找不到建筑记录"
        case .notLoggedIn:
            return "请先登录"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}

// MARK: - JSON 解码辅助

/// 建筑模板文件结构
struct BuildingTemplatesFile: Codable {
    let templates: [BuildingTemplate]
}
