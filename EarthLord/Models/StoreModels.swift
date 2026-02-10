//
//  StoreModels.swift
//  EarthLord
//
//  内购数据模型
//  定义所有产品ID、VIP等级、用户权益等
//

import Foundation
import SwiftUI

// MARK: - 产品ID枚举

/// 所有内购产品ID
enum StoreProductID: String, CaseIterable {
    // 订阅 - 幸存者VIP
    case survivorMonthly = "com.earthlord.vip.survivor.monthly"
    case survivorYearly = "com.earthlord.vip.survivor.yearly"

    // 订阅 - 领主VIP
    case lordMonthly = "com.earthlord.vip.lord.monthly"
    case lordYearly = "com.earthlord.vip.lord.yearly"

    // 消耗品 - 末日币
    case coins60 = "com.earthlord.coins.60"
    case coins360 = "com.earthlord.coins.360"
    case coins1280 = "com.earthlord.coins.1280"

    // 消耗品 - 物资包
    case packBasic = "com.earthlord.pack.basic"
    case packBuilder = "com.earthlord.pack.builder"
    case packElite = "com.earthlord.pack.elite"
    case packLegendary = "com.earthlord.pack.legendary"

    // 非消耗品 - 功能解锁
    case unlockSatellite = "com.earthlord.unlock.satellite"
    case unlockTerritory5 = "com.earthlord.unlock.territory5"
    case unlockRadar = "com.earthlord.unlock.radar"
    case unlockBackpack = "com.earthlord.unlock.backpack"

    /// 产品类型
    var productType: ProductType {
        switch self {
        case .survivorMonthly, .survivorYearly, .lordMonthly, .lordYearly:
            return .subscription
        case .coins60, .coins360, .coins1280,
             .packBasic, .packBuilder, .packElite, .packLegendary:
            return .consumable
        case .unlockSatellite, .unlockTerritory5, .unlockRadar, .unlockBackpack:
            return .nonConsumable
        }
    }

    /// 产品显示名称
    var displayName: String {
        switch self {
        case .survivorMonthly: return "幸存者VIP月卡"
        case .survivorYearly: return "幸存者VIP年卡"
        case .lordMonthly: return "领主VIP月卡"
        case .lordYearly: return "领主VIP年卡"
        case .coins60: return "60末日币"
        case .coins360: return "360末日币"
        case .coins1280: return "1280末日币"
        case .unlockSatellite: return "卫星通讯设备"
        case .unlockTerritory5: return "领地扩展包"
        case .unlockRadar: return "高级探索雷达"
        case .unlockBackpack: return "超级背包"
        case .packBasic: return "应急补给包"
        case .packBuilder: return "建造者工具箱"
        case .packElite: return "精英生存箱"
        case .packLegendary: return "传说军火库"
        }
    }

    /// 产品描述
    var description: String {
        switch self {
        case .survivorMonthly, .survivorYearly:
            return "领地10块、背包50kg、高级对讲机、每日奖励"
        case .lordMonthly, .lordYearly:
            return "无限领地、背包100kg、军用通讯、AI物品2次/天、建造2倍速、专属徽章"
        case .coins60: return "60枚末日币"
        case .coins360: return "360枚末日币（超值）"
        case .coins1280: return "1280枚末日币（最划算）"
        case .unlockSatellite: return "永久解锁无限通讯距离"
        case .unlockTerritory5: return "永久增加5个领地槽位"
        case .unlockRadar: return "探索时显示稀有POI"
        case .unlockBackpack: return "永久增加30kg背包容量"
        case .packBasic: return "水、食物、绷带、木材，新手应急必备"
        case .packBuilder: return "大量建材，建造营火+避难所绰绰有余"
        case .packElite: return "全面补给+30末日币，建造2-3个建筑"
        case .packLegendary: return "海量物资+100末日币，建造所有基础建筑"
        }
    }

    /// 产品图标
    var iconName: String {
        switch self {
        case .survivorMonthly, .survivorYearly: return "shield.fill"
        case .lordMonthly, .lordYearly: return "crown.fill"
        case .coins60, .coins360, .coins1280: return "bitcoinsign.circle.fill"
        case .unlockSatellite: return "antenna.radiowaves.left.and.right"
        case .unlockTerritory5: return "map.fill"
        case .unlockRadar: return "dot.radiowaves.left.and.right"
        case .unlockBackpack: return "bag.fill"
        case .packBasic: return "cross.case.fill"
        case .packBuilder: return "hammer.fill"
        case .packElite: return "shield.lefthalf.filled"
        case .packLegendary: return "star.circle.fill"
        }
    }

    /// 所有订阅产品
    static var subscriptions: [StoreProductID] {
        [.survivorMonthly, .survivorYearly, .lordMonthly, .lordYearly]
    }

    /// 所有消耗品（末日币）
    static var consumables: [StoreProductID] {
        [.coins60, .coins360, .coins1280]
    }

    /// 所有物资包
    static var resourcePacks: [StoreProductID] {
        [.packBasic, .packBuilder, .packElite, .packLegendary]
    }

    /// 所有非消耗品
    static var nonConsumables: [StoreProductID] {
        [.unlockSatellite, .unlockTerritory5, .unlockRadar, .unlockBackpack]
    }

    /// 对应VIP等级
    var vipTier: VIPTier? {
        switch self {
        case .survivorMonthly, .survivorYearly: return .survivor
        case .lordMonthly, .lordYearly: return .lord
        default: return nil
        }
    }

    /// 是否为物资包
    var isResourcePack: Bool {
        switch self {
        case .packBasic, .packBuilder, .packElite, .packLegendary: return true
        default: return false
        }
    }

    /// 备用价格（StoreKit 未加载时显示）
    var fallbackPrice: String {
        switch self {
        case .survivorMonthly: return "¥12"
        case .survivorYearly: return "¥98"
        case .lordMonthly: return "¥30"
        case .lordYearly: return "¥268"
        case .coins60: return "¥6"
        case .coins360: return "¥30"
        case .coins1280: return "¥98"
        case .packBasic: return "¥6"
        case .packBuilder: return "¥18"
        case .packElite: return "¥38"
        case .packLegendary: return "¥98"
        case .unlockSatellite: return "¥12"
        case .unlockTerritory5: return "¥6"
        case .unlockRadar: return "¥12"
        case .unlockBackpack: return "¥18"
        }
    }

    /// 消耗品币数
    var coinAmount: Int? {
        switch self {
        case .coins60: return 60
        case .coins360: return 360
        case .coins1280: return 1280
        default: return nil
        }
    }
}

// MARK: - 产品类型

enum ProductType: String, Codable {
    case subscription
    case consumable
    case nonConsumable = "non_consumable"
}

// MARK: - VIP等级

enum VIPTier: String, Codable, Comparable {
    case none
    case survivor
    case lord

    var displayName: String {
        switch self {
        case .none: return "免费用户"
        case .survivor: return "幸存者VIP"
        case .lord: return "领主VIP"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "person.fill"
        case .survivor: return "shield.fill"
        case .lord: return "crown.fill"
        }
    }

    /// 领地上限
    var maxTerritoryCount: Int {
        switch self {
        case .none: return 3
        case .survivor: return 10
        case .lord: return 999
        }
    }

    /// 背包最大重量（kg）
    var baseMaxWeight: Double {
        switch self {
        case .none: return 30.0
        case .survivor: return 50.0
        case .lord: return 100.0
        }
    }

    /// 背包最大容量（升）
    var baseMaxVolume: Double {
        switch self {
        case .none: return 50.0
        case .survivor: return 80.0
        case .lord: return 150.0
        }
    }

    /// 建造速度倍率
    var buildSpeedMultiplier: Double {
        switch self {
        case .none: return 1.0
        case .survivor: return 1.0
        case .lord: return 2.0
        }
    }

    /// VIP徽章颜色（hex）
    var badgeColorHex: String {
        switch self {
        case .none: return "808080"
        case .survivor: return "4CAF50"
        case .lord: return "FFD700"
        }
    }

    static func < (lhs: VIPTier, rhs: VIPTier) -> Bool {
        let order: [VIPTier] = [.none, .survivor, .lord]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

// MARK: - 用户权益

struct UserEntitlements: Codable {
    let userId: UUID
    var vipTier: String
    var vipExpiresAt: Date?
    var coinBalance: Int
    var hasSatelliteDevice: Bool
    var extraTerritorySlots: Int
    var hasPremiumRadar: Bool
    var extraBackpackKg: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case vipTier = "vip_tier"
        case vipExpiresAt = "vip_expires_at"
        case coinBalance = "coin_balance"
        case hasSatelliteDevice = "has_satellite_device"
        case extraTerritorySlots = "extra_territory_slots"
        case hasPremiumRadar = "has_premium_radar"
        case extraBackpackKg = "extra_backpack_kg"
    }

    /// 当前VIP等级（考虑过期）
    var currentVIPTier: VIPTier {
        let tier = VIPTier(rawValue: vipTier) ?? .none
        if tier != .none, let expires = vipExpiresAt, expires < Date() {
            return .none
        }
        return tier
    }

    /// VIP是否有效
    var isVIPActive: Bool {
        currentVIPTier != .none
    }

    /// 默认权益
    static var defaultEntitlements: UserEntitlements {
        UserEntitlements(
            userId: UUID(),
            vipTier: "none",
            vipExpiresAt: nil,
            coinBalance: 0,
            hasSatelliteDevice: false,
            extraTerritorySlots: 0,
            hasPremiumRadar: false,
            extraBackpackKg: 0
        )
    }
}

// MARK: - 购买记录

struct PurchaseRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let productId: String
    let transactionId: String
    let originalTransactionId: String
    let purchaseDate: Date
    let expiresDate: Date?
    let productType: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case transactionId = "transaction_id"
        case originalTransactionId = "original_transaction_id"
        case purchaseDate = "purchase_date"
        case expiresDate = "expires_date"
        case productType = "product_type"
        case createdAt = "created_at"
    }
}

// MARK: - 末日币流水

struct CoinTransaction: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let amount: Int
    let balanceAfter: Int
    let reason: String
    let referenceId: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case amount
        case balanceAfter = "balance_after"
        case reason
        case referenceId = "reference_id"
        case createdAt = "created_at"
    }
}

// MARK: - 物资包定义

/// 物资包内的单个物品
struct ResourcePackItem {
    let itemId: String
    let name: String
    let quantity: Int
    let rarity: String
    let icon: String
}

/// 物资包定义
struct ResourcePackDefinition {
    let productId: StoreProductID
    let name: String
    let subtitle: String
    let tag: String?
    let bonusCoins: Int
    let items: [ResourcePackItem]
    let themeColor: Color

    /// 物品总数
    var totalItemCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    /// 物品种类数
    var itemTypeCount: Int {
        items.count
    }
}

/// 所有物资包定义
enum ResourcePackCatalog {
    static let basicPack = ResourcePackDefinition(
        productId: .packBasic,
        name: "应急补给包",
        subtitle: "新手入门，应急续命",
        tag: nil,
        bonusCoins: 0,
        items: [
            ResourcePackItem(itemId: "water_bottle", name: "矿泉水", quantity: 5, rarity: "common", icon: "drop.fill"),
            ResourcePackItem(itemId: "canned_food", name: "罐头食品", quantity: 5, rarity: "common", icon: "takeoutbag.and.cup.and.straw.fill"),
            ResourcePackItem(itemId: "bandage", name: "绷带", quantity: 5, rarity: "common", icon: "cross.case.fill"),
            ResourcePackItem(itemId: "wood", name: "木材", quantity: 10, rarity: "common", icon: "leaf.fill"),
        ],
        themeColor: Color(white: 0.6) // 普通-白/灰
    )

    static let builderPack = ResourcePackDefinition(
        productId: .packBuilder,
        name: "建造者工具箱",
        subtitle: "中期建造加速，省去探索收集",
        tag: "热门",
        bonusCoins: 0,
        items: [
            ResourcePackItem(itemId: "wood", name: "木材", quantity: 30, rarity: "common", icon: "leaf.fill"),
            ResourcePackItem(itemId: "stone", name: "石材", quantity: 20, rarity: "common", icon: "mountain.2.fill"),
            ResourcePackItem(itemId: "scrap_metal", name: "废金属", quantity: 10, rarity: "common", icon: "gearshape.fill"),
            ResourcePackItem(itemId: "rope", name: "绳子", quantity: 3, rarity: "common", icon: "lasso"),
            ResourcePackItem(itemId: "medicine", name: "药品", quantity: 5, rarity: "uncommon", icon: "pills.fill"),
        ],
        themeColor: Color(red: 0.2, green: 0.8, blue: 0.4) // 优良-绿
    )

    static let elitePack = ResourcePackDefinition(
        productId: .packElite,
        name: "精英生存箱",
        subtitle: "全面补给，兼顾建造和生存",
        tag: "超值",
        bonusCoins: 30,
        items: [
            ResourcePackItem(itemId: "water_bottle", name: "矿泉水", quantity: 10, rarity: "common", icon: "drop.fill"),
            ResourcePackItem(itemId: "canned_food", name: "罐头食品", quantity: 10, rarity: "common", icon: "takeoutbag.and.cup.and.straw.fill"),
            ResourcePackItem(itemId: "medicine", name: "药品", quantity: 10, rarity: "uncommon", icon: "pills.fill"),
            ResourcePackItem(itemId: "wood", name: "木材", quantity: 50, rarity: "common", icon: "leaf.fill"),
            ResourcePackItem(itemId: "stone", name: "石材", quantity: 30, rarity: "common", icon: "mountain.2.fill"),
            ResourcePackItem(itemId: "scrap_metal", name: "废金属", quantity: 20, rarity: "common", icon: "gearshape.fill"),
            ResourcePackItem(itemId: "flashlight", name: "手电筒", quantity: 2, rarity: "uncommon", icon: "flashlight.on.fill"),
            ResourcePackItem(itemId: "rope", name: "绳子", quantity: 5, rarity: "common", icon: "lasso"),
        ],
        themeColor: Color(red: 0.3, green: 0.7, blue: 1.0) // 稀有-蓝
    )

    static let legendaryPack = ResourcePackDefinition(
        productId: .packLegendary,
        name: "传说军火库",
        subtitle: "终极大礼包，海量高级资源",
        tag: "最划算",
        bonusCoins: 100,
        items: [
            ResourcePackItem(itemId: "water_bottle", name: "矿泉水", quantity: 20, rarity: "common", icon: "drop.fill"),
            ResourcePackItem(itemId: "canned_food", name: "罐头食品", quantity: 20, rarity: "common", icon: "takeoutbag.and.cup.and.straw.fill"),
            ResourcePackItem(itemId: "medicine", name: "药品", quantity: 20, rarity: "uncommon", icon: "pills.fill"),
            ResourcePackItem(itemId: "bandage", name: "绷带", quantity: 20, rarity: "common", icon: "cross.case.fill"),
            ResourcePackItem(itemId: "wood", name: "木材", quantity: 100, rarity: "common", icon: "leaf.fill"),
            ResourcePackItem(itemId: "stone", name: "石材", quantity: 60, rarity: "common", icon: "mountain.2.fill"),
            ResourcePackItem(itemId: "scrap_metal", name: "废金属", quantity: 40, rarity: "common", icon: "gearshape.fill"),
            ResourcePackItem(itemId: "glass", name: "玻璃", quantity: 20, rarity: "uncommon", icon: "square.split.diagonal.fill"),
            ResourcePackItem(itemId: "flashlight", name: "手电筒", quantity: 3, rarity: "uncommon", icon: "flashlight.on.fill"),
            ResourcePackItem(itemId: "rope", name: "绳子", quantity: 10, rarity: "common", icon: "lasso"),
        ],
        themeColor: Color(red: 1.0, green: 0.6, blue: 0.1) // 传说-橙
    )

    /// 所有物资包
    static let allPacks: [ResourcePackDefinition] = [
        basicPack, builderPack, elitePack, legendaryPack
    ]

    /// 根据产品ID获取物资包定义
    static func pack(for productId: StoreProductID) -> ResourcePackDefinition? {
        allPacks.first { $0.productId == productId }
    }
}

// MARK: - 服务端验证请求体

struct ValidatePurchaseRequest: Codable {
    let productId: String
    let transactionId: String
    let originalTransactionId: String
    let purchaseDate: String
    let expiresDate: String?
    let productType: String
    let jwsRepresentation: String?
}

struct ValidatePurchaseResponse: Codable {
    let success: Bool?
    let message: String?
    let error: String?
}
