//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器
//  负责从 Supabase 加载、添加、删除背包物品
//

import Foundation
import Combine
import Supabase

/// 背包物品（从数据库加载）
struct InventoryItem: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let itemId: String
    var quantity: Int
    let quality: String?
    let obtainedAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case quality
        case obtainedAt = "obtained_at"
        case updatedAt = "updated_at"
    }

    /// 获取物品定义
    func getDefinition(from definitions: [DBItemDefinition]) -> DBItemDefinition? {
        return definitions.first { $0.id == itemId }
    }

    /// 计算总重量
    func totalWeight(from definitions: [DBItemDefinition]) -> Double {
        guard let def = getDefinition(from: definitions) else { return 0 }
        return def.weight * Double(quantity)
    }

    /// 计算总体积
    func totalVolume(from definitions: [DBItemDefinition]) -> Double {
        guard let def = getDefinition(from: definitions) else { return 0 }
        return def.volume * Double(quantity)
    }

    /// 品质显示名称
    var qualityDisplayName: String? {
        guard let q = quality else { return nil }
        switch q {
        case "fresh": return "新鲜"
        case "normal": return "正常"
        case "stale": return "陈旧"
        case "spoiled": return "变质"
        default: return q
        }
    }
}

/// 新建背包物品（用于插入）
struct NewInventoryItem: Codable {
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

/// 背包管理器
@MainActor
class InventoryManager: ObservableObject {

    // MARK: - 单例

    static let shared = InventoryManager()

    // MARK: - 发布属性

    /// 背包物品列表
    @Published var items: [InventoryItem] = []

    /// 物品定义缓存
    @Published var itemDefinitions: [DBItemDefinition] = []

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 最大负重（kg）— 根据VIP等级和购买动态计算
    var maxWeight: Double {
        StoreManager.shared.maxBackpackWeight
    }

    /// 最大容量（升）— 根据VIP等级动态计算
    var maxVolume: Double {
        StoreManager.shared.maxBackpackVolume
    }

    // MARK: - 计算属性

    /// 当前总重量
    var currentWeight: Double {
        items.reduce(0) { $0 + $1.totalWeight(from: itemDefinitions) }
    }

    /// 当前总体积
    var currentVolume: Double {
        items.reduce(0) { $0 + $1.totalVolume(from: itemDefinitions) }
    }

    /// 重量使用百分比
    var weightPercentage: Double {
        min(currentWeight / maxWeight, 1.0)
    }

    /// 体积使用百分比
    var volumePercentage: Double {
        min(currentVolume / maxVolume, 1.0)
    }

    /// 背包是否已满
    var isFull: Bool {
        currentWeight >= maxWeight || currentVolume >= maxVolume
    }

    // MARK: - 私有属性

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        AuthManager.shared.supabaseClient
    }

    // MARK: - 初始化

    private init() {
        print("🎒 [背包] InventoryManager 初始化")
    }

    // MARK: - 公开方法

    /// 加载物品定义
    func loadItemDefinitions() async {
        guard itemDefinitions.isEmpty else { return }

        do {
            let definitions: [DBItemDefinition] = try await supabase
                .from("item_definitions")
                .select()
                .execute()
                .value

            itemDefinitions = definitions
            print("🎒 [背包] 加载了 \(definitions.count) 种物品定义")
        } catch {
            print("❌ [背包] 加载物品定义失败: \(error)")
            errorMessage = "加载物品定义失败"
        }
    }

    /// 加载背包数据
    func loadInventory() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "请先登录"
            return
        }

        isLoading = true
        errorMessage = nil

        // 先加载物品定义
        await loadItemDefinitions()

        do {
            let inventoryItems: [InventoryItem] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("obtained_at", ascending: false)
                .execute()
                .value

            items = inventoryItems
            print("🎒 [背包] 加载了 \(inventoryItems.count) 个物品")
        } catch {
            print("❌ [背包] 加载背包失败: \(error)")
            errorMessage = "加载背包失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 添加物品到背包
    /// - Parameters:
    ///   - itemId: 物品定义 ID
    ///   - quantity: 数量
    ///   - quality: 品质（可选）
    func addItem(itemId: String, quantity: Int, quality: String? = nil) async -> Bool {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "请先登录"
            return false
        }

        do {
            // 检查是否已有相同物品（同 itemId 和 quality）
            if let existingIndex = items.firstIndex(where: {
                $0.itemId == itemId && $0.quality == quality
            }) {
                // 更新数量
                let newQuantity = items[existingIndex].quantity + quantity
                try await supabase
                    .from("inventory_items")
                    .update(["quantity": newQuantity])
                    .eq("id", value: items[existingIndex].id.uuidString)
                    .execute()

                items[existingIndex].quantity = newQuantity
                print("🎒 [背包] 更新物品数量: \(itemId) x\(newQuantity)")
            } else {
                // 插入新物品
                let newItem = NewInventoryItem(
                    userId: userId.uuidString,
                    itemId: itemId,
                    quantity: quantity,
                    quality: quality
                )

                try await supabase
                    .from("inventory_items")
                    .insert(newItem)
                    .execute()

                // 重新加载背包
                await loadInventory()
                print("🎒 [背包] 添加新物品: \(itemId) x\(quantity)")
            }

            return true
        } catch {
            print("❌ [背包] 添加物品失败: \(error)")
            errorMessage = "添加物品失败"
            return false
        }
    }

    /// 使用/消耗物品
    /// - Parameters:
    ///   - item: 背包物品
    ///   - quantity: 使用数量
    func useItem(_ item: InventoryItem, quantity: Int = 1) async -> Bool {
        guard quantity <= item.quantity else {
            errorMessage = "数量不足"
            return false
        }

        do {
            let newQuantity = item.quantity - quantity

            if newQuantity <= 0 {
                // 删除物品
                try await supabase
                    .from("inventory_items")
                    .delete()
                    .eq("id", value: item.id.uuidString)
                    .execute()

                items.removeAll { $0.id == item.id }
                print("🎒 [背包] 删除物品: \(item.itemId)")
            } else {
                // 更新数量
                try await supabase
                    .from("inventory_items")
                    .update(["quantity": newQuantity])
                    .eq("id", value: item.id.uuidString)
                    .execute()

                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].quantity = newQuantity
                }
                print("🎒 [背包] 使用物品: \(item.itemId)，剩余 \(newQuantity)")
            }

            return true
        } catch {
            print("❌ [背包] 使用物品失败: \(error)")
            errorMessage = "使用物品失败"
            return false
        }
    }

    /// 丢弃物品
    func discardItem(_ item: InventoryItem) async -> Bool {
        do {
            try await supabase
                .from("inventory_items")
                .delete()
                .eq("id", value: item.id.uuidString)
                .execute()

            items.removeAll { $0.id == item.id }
            print("🎒 [背包] 丢弃物品: \(item.itemId)")
            return true
        } catch {
            print("❌ [背包] 丢弃物品失败: \(error)")
            errorMessage = "丢弃物品失败"
            return false
        }
    }

    /// 按分类筛选物品
    func items(for category: String?) -> [InventoryItem] {
        guard let category = category else { return items }
        return items.filter { item in
            guard let def = item.getDefinition(from: itemDefinitions) else { return false }
            return def.category == category
        }
    }

    /// 搜索物品
    func searchItems(query: String) -> [InventoryItem] {
        guard !query.isEmpty else { return items }
        let lowercasedQuery = query.lowercased()
        return items.filter { item in
            guard let def = item.getDefinition(from: itemDefinitions) else { return false }
            return def.name.lowercased().contains(lowercasedQuery) ||
                   def.description?.lowercased().contains(lowercasedQuery) ?? false
        }
    }

    /// 获取所有分类
    var categories: [String] {
        let cats = Set(itemDefinitions.map { $0.category })
        return Array(cats).sorted()
    }

    /// 清除错误
    func clearError() {
        errorMessage = nil
    }

    // MARK: - 交易系统内部方法

    /// 获取指定物品的可用数量
    /// - Parameter itemId: 物品定义 ID
    /// - Returns: 可用数量
    func getAvailableQuantity(itemId: String) -> Int {
        return items.filter { $0.itemId == itemId }.reduce(0) { $0 + $1.quantity }
    }

    /// 为交易扣除物品（内部方法）
    /// - Parameters:
    ///   - itemId: 物品定义 ID
    ///   - quantity: 扣除数量
    /// - Returns: 是否成功
    func deductItemForTrade(itemId: String, quantity: Int) async -> Bool {
        guard let userId = AuthManager.shared.currentUser?.id else {
            print("❌ [背包] 交易扣除失败：未登录")
            return false
        }

        // 查找背包中对应物品
        guard let existingIndex = items.firstIndex(where: { $0.itemId == itemId }) else {
            print("❌ [背包] 交易扣除失败：物品不存在")
            return false
        }

        let existingItem = items[existingIndex]
        guard existingItem.quantity >= quantity else {
            print("❌ [背包] 交易扣除失败：数量不足")
            return false
        }

        do {
            let newQuantity = existingItem.quantity - quantity

            if newQuantity <= 0 {
                // 删除物品
                try await supabase
                    .from("inventory_items")
                    .delete()
                    .eq("id", value: existingItem.id.uuidString)
                    .execute()

                items.removeAll { $0.id == existingItem.id }
                print("🎒 [背包] 交易扣除：删除物品 \(itemId)")
            } else {
                // 更新数量
                try await supabase
                    .from("inventory_items")
                    .update(["quantity": newQuantity])
                    .eq("id", value: existingItem.id.uuidString)
                    .execute()

                items[existingIndex].quantity = newQuantity
                print("🎒 [背包] 交易扣除：\(itemId) 剩余 \(newQuantity)")
            }

            return true
        } catch {
            print("❌ [背包] 交易扣除数据库错误: \(error)")
            return false
        }
    }

    /// 为交易添加物品到当前用户背包（内部方法）
    /// - Parameters:
    ///   - itemId: 物品定义 ID
    ///   - quantity: 添加数量
    /// - Returns: 是否成功
    func addItemForTrade(itemId: String, quantity: Int) async -> Bool {
        return await addItem(itemId: itemId, quantity: quantity, quality: nil)
    }

    /// 为交易添加物品到指定用户背包（内部方法）
    /// - Parameters:
    ///   - userId: 目标用户 ID
    ///   - itemId: 物品定义 ID
    ///   - quantity: 添加数量
    /// - Returns: 是否成功
    func addItemForTradeToUser(userId: UUID, itemId: String, quantity: Int) async -> Bool {
        do {
            // 检查目标用户是否已有相同物品
            let existingItems: [InventoryItem] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("item_id", value: itemId)
                .execute()
                .value

            if let existingItem = existingItems.first {
                // 更新数量
                let newQuantity = existingItem.quantity + quantity
                try await supabase
                    .from("inventory_items")
                    .update(["quantity": newQuantity])
                    .eq("id", value: existingItem.id.uuidString)
                    .execute()

                print("🎒 [背包] 交易添加到用户 \(userId)：更新 \(itemId) x\(newQuantity)")
            } else {
                // 插入新物品
                let newItem = NewInventoryItem(
                    userId: userId.uuidString,
                    itemId: itemId,
                    quantity: quantity,
                    quality: nil
                )

                try await supabase
                    .from("inventory_items")
                    .insert(newItem)
                    .execute()

                print("🎒 [背包] 交易添加到用户 \(userId)：新增 \(itemId) x\(quantity)")
            }

            return true
        } catch {
            print("❌ [背包] 交易添加到用户背包失败: \(error)")
            return false
        }
    }

    // MARK: - 开发者测试方法

    #if DEBUG
    /// 添加测试资源（用于建造系统测试）
    func addTestResources() async -> Bool {
        print("🎒 [背包] 开始添加测试资源...")

        let testResources: [(id: String, name: String, quantity: Int)] = [
            ("wood", "木材", 200),
            ("stone", "石头", 150),
            ("metal", "金属", 100),
            ("glass", "玻璃", 50)
        ]

        for resource in testResources {
            let success = await addItem(itemId: resource.id, quantity: resource.quantity, quality: nil)
            if success {
                print("🎒 [背包] ✅ 添加 \(resource.name) x\(resource.quantity)")
            } else {
                print("🎒 [背包] ❌ 添加 \(resource.name) 失败")
                return false
            }
        }

        print("🎒 [背包] ✅ 测试资源添加完成")
        return true
    }

    /// 清空所有背包物品（用于测试）
    func clearAllItems() async -> Bool {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "请先登录"
            return false
        }

        do {
            try await supabase
                .from("inventory_items")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()

            items = []
            print("🎒 [背包] ✅ 已清空所有物品")
            return true
        } catch {
            print("❌ [背包] 清空背包失败: \(error)")
            return false
        }
    }
    #endif
}
