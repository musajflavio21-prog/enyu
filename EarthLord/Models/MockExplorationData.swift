//
//  MockExplorationData.swift
//  EarthLord
//
//  探索模块测试假数据
//  用于开发和测试探索功能，正式版本从服务器获取
//

import Foundation
import CoreLocation

// MARK: - POI 兴趣点相关

/// POI 发现状态
enum POIStatus: String, Codable {
    case undiscovered   // 未发现（地图上不显示或显示为问号）
    case discovered     // 已发现（可以看到详情）
    case looted         // 已搜刮（物资已被搜空）
}

/// POI 类型
enum POIType: String, Codable {
    case supermarket    // 超市
    case hospital       // 医院
    case gasStation     // 加油站
    case pharmacy       // 药店
    case factory        // 工厂
    case warehouse      // 仓库
    case residence      // 住宅
}

/// 兴趣点（Point of Interest）模型
struct POI: Identifiable, Codable {
    let id: String
    let name: String                    // 地点名称
    let type: POIType                   // 地点类型
    let coordinate: Coordinate          // 坐标
    var status: POIStatus               // 发现状态
    let hasLoot: Bool                   // 是否有物资
    let dangerLevel: Int                // 危险等级（1-5）
    let description: String             // 描述

    /// 简单坐标结构（用于 Codable）
    struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double

        func toCLLocationCoordinate2D() -> CLLocationCoordinate2D {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
}

/// POI 假数据列表
/// 用途：在地图上显示可探索的兴趣点
struct MockPOIData {

    /// 5个不同状态的兴趣点
    static let poiList: [POI] = [
        // 废弃超市：已发现，有物资
        POI(
            id: "poi_001",
            name: "废弃超市",
            type: .supermarket,
            coordinate: POI.Coordinate(latitude: 31.2304, longitude: 121.4737),
            status: .discovered,
            hasLoot: true,
            dangerLevel: 2,
            description: "曾经繁忙的大型超市，现在杂草丛生。货架上可能还有些遗漏的物资。"
        ),

        // 医院废墟：已发现，已被搜空
        POI(
            id: "poi_002",
            name: "医院废墟",
            type: .hospital,
            coordinate: POI.Coordinate(latitude: 31.2350, longitude: 121.4800),
            status: .looted,
            hasLoot: false,
            dangerLevel: 4,
            description: "城市中心医院的废墟，已经被多次搜刮。小心可能存在的危险生物。"
        ),

        // 加油站：未发现
        POI(
            id: "poi_003",
            name: "加油站",
            type: .gasStation,
            coordinate: POI.Coordinate(latitude: 31.2280, longitude: 121.4650),
            status: .undiscovered,
            hasLoot: true,
            dangerLevel: 3,
            description: "路边的废弃加油站，可能有燃料和便利店物资。"
        ),

        // 药店废墟：已发现，有物资
        POI(
            id: "poi_004",
            name: "药店废墟",
            type: .pharmacy,
            coordinate: POI.Coordinate(latitude: 31.2320, longitude: 121.4780),
            status: .discovered,
            hasLoot: true,
            dangerLevel: 1,
            description: "街角的小药店，墙壁破损但结构完整。可能有急需的医疗用品。"
        ),

        // 工厂废墟：未发现
        POI(
            id: "poi_005",
            name: "工厂废墟",
            type: .factory,
            coordinate: POI.Coordinate(latitude: 31.2400, longitude: 121.4850),
            status: .undiscovered,
            hasLoot: true,
            dangerLevel: 5,
            description: "郊区的大型工厂，可能有大量工业材料，但危险系数极高。"
        )
    ]
}


// MARK: - 物品定义相关

/// 物品分类
enum ItemCategory: String, Codable, CaseIterable {
    case water      = "水类"
    case food       = "食物"
    case medical    = "医疗"
    case material   = "材料"
    case tool       = "工具"
    case weapon     = "武器"
    case clothing   = "服装"
    case misc       = "杂项"
}

/// 物品稀有度
enum ItemRarity: String, Codable, CaseIterable {
    case common     = "普通"      // 白色
    case uncommon   = "优良"      // 绿色
    case rare       = "稀有"      // 蓝色
    case epic       = "史诗"      // 紫色
    case legendary  = "传说"      // 橙色
}

/// 物品品质（用于可消耗品）
enum ItemQuality: String, Codable {
    case fresh      = "新鲜"      // 100% 效果
    case normal     = "正常"      // 80% 效果
    case stale      = "陈旧"      // 50% 效果
    case spoiled    = "变质"      // 无法使用
}

/// 物品定义（静态属性表）
/// 用途：定义每种物品的基础属性，用于物品生成和显示
struct ItemDefinition: Identifiable, Codable {
    let id: String              // 物品ID
    let name: String            // 中文名称
    let category: ItemCategory  // 分类
    let weight: Double          // 单个重量（kg）
    let volume: Double          // 单个体积（升）
    let rarity: ItemRarity      // 稀有度
    let stackLimit: Int         // 堆叠上限
    let description: String     // 物品描述
    let hasQuality: Bool        // 是否有品质属性（食物、药品等）
}

/// 物品定义表假数据
/// 用途：作为物品属性的查找表
struct MockItemDefinitions {

    static let definitions: [String: ItemDefinition] = [
        // 水类
        "item_water_bottle": ItemDefinition(
            id: "item_water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            stackLimit: 20,
            description: "密封的瓶装水，干净安全。",
            hasQuality: true
        ),

        // 食物
        "item_canned_food": ItemDefinition(
            id: "item_canned_food",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            stackLimit: 15,
            description: "密封良好的罐头，保质期较长。",
            hasQuality: true
        ),

        // 医疗
        "item_bandage": ItemDefinition(
            id: "item_bandage",
            name: "绷带",
            category: .medical,
            weight: 0.1,
            volume: 0.1,
            rarity: .common,
            stackLimit: 30,
            description: "基础医疗用品，用于包扎伤口。",
            hasQuality: false
        ),

        "item_medicine": ItemDefinition(
            id: "item_medicine",
            name: "药品",
            category: .medical,
            weight: 0.05,
            volume: 0.05,
            rarity: .uncommon,
            stackLimit: 20,
            description: "常见的止痛药或消炎药。",
            hasQuality: true
        ),

        // 材料
        "item_wood": ItemDefinition(
            id: "item_wood",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 3.0,
            rarity: .common,
            stackLimit: 50,
            description: "建筑和制作的基础材料。",
            hasQuality: false
        ),

        "item_scrap_metal": ItemDefinition(
            id: "item_scrap_metal",
            name: "废金属",
            category: .material,
            weight: 1.5,
            volume: 1.0,
            rarity: .common,
            stackLimit: 50,
            description: "各种废弃的金属零件，可以回收利用。",
            hasQuality: false
        ),

        // 工具
        "item_flashlight": ItemDefinition(
            id: "item_flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            stackLimit: 5,
            description: "便携式照明工具，夜间探索必备。",
            hasQuality: false
        ),

        "item_rope": ItemDefinition(
            id: "item_rope",
            name: "绳子",
            category: .tool,
            weight: 0.8,
            volume: 0.5,
            rarity: .common,
            stackLimit: 10,
            description: "结实的尼龙绳，用途广泛。",
            hasQuality: false
        )
    ]

    /// 根据ID获取物品定义
    static func getDefinition(for itemId: String) -> ItemDefinition? {
        return definitions[itemId]
    }
}


// MARK: - 背包物品相关

/// 背包物品实例（带数量和品质）
/// 用途：表示玩家背包中的具体物品
struct BackpackItem: Identifiable, Codable {
    let id: String              // 实例ID（唯一）
    let itemId: String          // 物品定义ID
    var quantity: Int           // 数量
    let quality: ItemQuality?   // 品质（可选，部分物品没有品质）
    let obtainedAt: Date        // 获得时间

    /// 获取物品定义
    var definition: ItemDefinition? {
        return MockItemDefinitions.getDefinition(for: itemId)
    }

    /// 计算总重量
    var totalWeight: Double {
        guard let def = definition else { return 0 }
        return def.weight * Double(quantity)
    }

    /// 计算总体积
    var totalVolume: Double {
        guard let def = definition else { return 0 }
        return def.volume * Double(quantity)
    }
}

/// 背包假数据
/// 用途：模拟玩家背包中的物品列表
struct MockBackpackData {

    /// 背包容量配置
    static let maxWeight: Double = 30.0     // 最大负重（kg）
    static let maxVolume: Double = 50.0     // 最大容量（升）

    /// 背包物品列表（8种不同类型的物品）
    static let items: [BackpackItem] = [
        // 水类：矿泉水 x5（正常品质）
        BackpackItem(
            id: "bp_001",
            itemId: "item_water_bottle",
            quantity: 5,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-3600)
        ),

        // 食物：罐头食品 x3（新鲜品质）
        BackpackItem(
            id: "bp_002",
            itemId: "item_canned_food",
            quantity: 3,
            quality: .fresh,
            obtainedAt: Date().addingTimeInterval(-7200)
        ),

        // 医疗：绷带 x10（无品质）
        BackpackItem(
            id: "bp_003",
            itemId: "item_bandage",
            quantity: 10,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-1800)
        ),

        // 医疗：药品 x4（正常品质）
        BackpackItem(
            id: "bp_004",
            itemId: "item_medicine",
            quantity: 4,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-5400)
        ),

        // 材料：木材 x8（无品质）
        BackpackItem(
            id: "bp_005",
            itemId: "item_wood",
            quantity: 8,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-10800)
        ),

        // 材料：废金属 x6（无品质）
        BackpackItem(
            id: "bp_006",
            itemId: "item_scrap_metal",
            quantity: 6,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-9000)
        ),

        // 工具：手电筒 x1（无品质）
        BackpackItem(
            id: "bp_007",
            itemId: "item_flashlight",
            quantity: 1,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-86400)
        ),

        // 工具：绳子 x2（无品质）
        BackpackItem(
            id: "bp_008",
            itemId: "item_rope",
            quantity: 2,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-43200)
        )
    ]

    /// 计算背包当前总重量
    static var currentWeight: Double {
        return items.reduce(0) { $0 + $1.totalWeight }
    }

    /// 计算背包当前总体积
    static var currentVolume: Double {
        return items.reduce(0) { $0 + $1.totalVolume }
    }

    /// 背包是否超重
    static var isOverweight: Bool {
        return currentWeight > maxWeight
    }
}


// MARK: - 探索结果相关

/// 获得物品记录
/// 用途：记录单次探索获得的物品
struct LootRecord: Identifiable, Codable {
    let id: String
    let itemId: String          // 物品定义ID
    let quantity: Int           // 获得数量
    let quality: ItemQuality?   // 品质（可选）

    /// 获取物品定义
    var definition: ItemDefinition? {
        return MockItemDefinitions.getDefinition(for: itemId)
    }

    /// 显示名称（带数量）
    var displayName: String {
        guard let def = definition else { return "未知物品 x\(quantity)" }
        return "\(def.name) x\(quantity)"
    }
}

/// 探索统计数据
/// 用途：记录和显示探索统计信息
struct ExplorationStats: Codable {
    // 本次探索数据
    let sessionDistance: Double         // 本次行走距离（米）
    let sessionArea: Double             // 本次探索面积（平方米）
    let sessionDuration: TimeInterval   // 本次探索时长（秒）
    let sessionLoot: [LootRecord]       // 本次获得物品

    // 累计数据
    let totalDistance: Double           // 累计行走距离（米）
    let totalArea: Double               // 累计探索面积（平方米）
    let totalExplorations: Int          // 累计探索次数

    // 排名数据
    let distanceRank: Int               // 行走距离排名
    let areaRank: Int                   // 探索面积排名

    // MARK: - 格式化显示

    /// 格式化本次距离
    var formattedSessionDistance: String {
        if sessionDistance >= 1000 {
            return String(format: "%.1f km", sessionDistance / 1000)
        } else {
            return String(format: "%.0f m", sessionDistance)
        }
    }

    /// 格式化累计距离
    var formattedTotalDistance: String {
        if totalDistance >= 1000 {
            return String(format: "%.1f km", totalDistance / 1000)
        } else {
            return String(format: "%.0f m", totalDistance)
        }
    }

    /// 格式化本次面积
    var formattedSessionArea: String {
        if sessionArea >= 1_000_000 {
            return String(format: "%.2f km²", sessionArea / 1_000_000)
        } else if sessionArea >= 10000 {
            return String(format: "%.1f 万m²", sessionArea / 10000)
        } else {
            return String(format: "%.0f m²", sessionArea)
        }
    }

    /// 格式化累计面积
    var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else if totalArea >= 10000 {
            return String(format: "%.1f 万m²", totalArea / 10000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    /// 格式化探索时长
    var formattedDuration: String {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)小时\(mins)分钟"
        } else {
            return "\(minutes)分\(seconds)秒"
        }
    }
}

/// 探索结果假数据
/// 用途：模拟单次探索结束后的结算界面
struct MockExplorationResult {

    /// 示例探索结果
    static let sampleResult = ExplorationStats(
        // 本次探索数据
        sessionDistance: 2500,              // 本次行走 2500 米
        sessionArea: 50000,                 // 本次探索 5 万平方米
        sessionDuration: 1800,              // 探索时长 30 分钟
        sessionLoot: [
            // 木材 x5
            LootRecord(id: "loot_001", itemId: "item_wood", quantity: 5, quality: nil),
            // 矿泉水 x3
            LootRecord(id: "loot_002", itemId: "item_water_bottle", quantity: 3, quality: .normal),
            // 罐头 x2
            LootRecord(id: "loot_003", itemId: "item_canned_food", quantity: 2, quality: .fresh),
            // 废金属 x3
            LootRecord(id: "loot_004", itemId: "item_scrap_metal", quantity: 3, quality: nil)
        ],

        // 累计数据
        totalDistance: 15000,               // 累计行走 15 公里
        totalArea: 250000,                  // 累计探索 25 万平方米
        totalExplorations: 12,              // 累计探索 12 次

        // 排名数据
        distanceRank: 42,                   // 行走距离排名第 42
        areaRank: 38                        // 探索面积排名第 38
    )

    /// 空探索结果（没有找到任何物品）
    static let emptyResult = ExplorationStats(
        sessionDistance: 800,
        sessionArea: 12000,
        sessionDuration: 600,
        sessionLoot: [],
        totalDistance: 15800,
        totalArea: 262000,
        totalExplorations: 13,
        distanceRank: 41,
        areaRank: 37
    )

    /// 丰收探索结果（找到大量物品）
    static let richResult = ExplorationStats(
        sessionDistance: 4200,
        sessionArea: 85000,
        sessionDuration: 3600,
        sessionLoot: [
            LootRecord(id: "loot_r01", itemId: "item_wood", quantity: 15, quality: nil),
            LootRecord(id: "loot_r02", itemId: "item_scrap_metal", quantity: 12, quality: nil),
            LootRecord(id: "loot_r03", itemId: "item_water_bottle", quantity: 8, quality: .fresh),
            LootRecord(id: "loot_r04", itemId: "item_canned_food", quantity: 6, quality: .fresh),
            LootRecord(id: "loot_r05", itemId: "item_bandage", quantity: 10, quality: nil),
            LootRecord(id: "loot_r06", itemId: "item_medicine", quantity: 4, quality: .normal),
            LootRecord(id: "loot_r07", itemId: "item_rope", quantity: 2, quality: nil)
        ],
        totalDistance: 19200,
        totalArea: 335000,
        totalExplorations: 14,
        distanceRank: 35,
        areaRank: 32
    )
}


// MARK: - 辅助扩展

extension ItemCategory {
    /// 分类图标
    var iconName: String {
        switch self {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .weapon: return "shield.fill"
        case .clothing: return "tshirt.fill"
        case .misc: return "archivebox.fill"
        }
    }
}

extension ItemRarity {
    /// 稀有度颜色（用于 SwiftUI）
    var colorName: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }
}

extension POIType {
    /// POI 类型图标
    var iconName: String {
        switch self {
        case .supermarket: return "cart.fill"
        case .hospital: return "cross.fill"
        case .gasStation: return "fuelpump.fill"
        case .pharmacy: return "pills.fill"
        case .factory: return "building.2.fill"
        case .warehouse: return "shippingbox.fill"
        case .residence: return "house.fill"
        }
    }

    /// POI 类型中文名称
    var displayName: String {
        switch self {
        case .supermarket: return "超市"
        case .hospital: return "医院"
        case .gasStation: return "加油站"
        case .pharmacy: return "药店"
        case .factory: return "工厂"
        case .warehouse: return "仓库"
        case .residence: return "住宅"
        }
    }
}

// MARK: - 真实POI（用于Day22搜刮系统）

/// 真实POI（从MapKit搜索得到的真实地点）
/// 用于探索时搜刮真实地点获得物品
struct RealPOI: Identifiable, Equatable {
    let id: String              // 唯一标识（基于坐标生成）
    let name: String            // 真实地点名称
    let type: POIType           // 映射到游戏类型
    let coordinate: CLLocationCoordinate2D
    var hasBeenScavenged: Bool  // 是否已搜刮（本次探索）

    /// 实现 Equatable
    static func == (lhs: RealPOI, rhs: RealPOI) -> Bool {
        return lhs.id == rhs.id
    }
}
