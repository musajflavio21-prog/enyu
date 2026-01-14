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

    /// 最大负重（kg）
    let maxWeight: Double = 30.0

    /// 最大容量（升）
    let maxVolume: Double = 50.0

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
}
