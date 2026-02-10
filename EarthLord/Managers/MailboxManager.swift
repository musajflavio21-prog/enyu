//
//  MailboxManager.swift
//  EarthLord
//
//  邮箱管理器
//  负责管理待领取物资：加载、领取、全部领取
//

import Foundation
import Combine
import Supabase

/// 邮箱管理器
@MainActor
class MailboxManager: ObservableObject {

    // MARK: - 单例

    static let shared = MailboxManager()

    // MARK: - 发布属性

    /// 待领取物品列表
    @Published var pendingItems: [PendingItem] = []

    /// 待领取物品数量（用于红点徽章）
    @Published var pendingCount: Int = 0

    /// 是否正在加载
    @Published var isLoading = false

    /// 是否正在领取
    @Published var isClaiming = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 成功信息
    @Published var successMessage: String?

    // MARK: - 私有属性

    private var supabase: SupabaseClient {
        AuthManager.shared.supabaseClient
    }

    // MARK: - 初始化

    private init() {
        print("📬 [邮箱] MailboxManager 初始化")
    }

    // MARK: - 公开方法

    /// 加载待领取物品
    func loadPendingItems() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        isLoading = true
        errorMessage = nil

        do {
            let items: [PendingItem] = try await supabase
                .from("pending_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            pendingItems = items
            pendingCount = items.reduce(0) { $0 + $1.quantity }
            print("📬 [邮箱] 加载了 \(items.count) 条待领取记录，共 \(pendingCount) 件物品")
        } catch {
            print("❌ [邮箱] 加载待领取物品失败: \(error)")
            errorMessage = "加载邮箱失败"
        }

        isLoading = false
    }

    /// 领取单个物品
    /// - Parameters:
    ///   - pendingItem: 待领取物品
    ///   - quantity: 领取数量
    /// - Returns: 是否成功
    func claimItem(_ pendingItem: PendingItem, quantity: Int) async -> Bool {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "请先登录"
            return false
        }

        // 领取前检查背包容量
        let inventoryManager = InventoryManager.shared
        let itemDef = inventoryManager.itemDefinitions.first { $0.id == pendingItem.itemId }
        if let def = itemDef {
            let addedWeight = def.weight * Double(quantity)
            let remainingCapacity = inventoryManager.maxWeight - inventoryManager.currentWeight
            if addedWeight > remainingCapacity {
                errorMessage = "背包容量不足（还需 \(String(format: "%.1f", addedWeight - remainingCapacity))kg 空间）"
                return false
            }
        }

        do {
            let params: [String: String] = [
                "p_user_id": userId.uuidString,
                "p_pending_item_id": pendingItem.id.uuidString,
                "p_quantity": String(quantity)
            ]

            let result: ClaimResult = try await supabase
                .rpc("claim_pending_item", params: params)
                .execute()
                .value

            if result.success {
                print("📬 [邮箱] 领取成功: \(pendingItem.itemId) x\(quantity)")

                // 更新本地状态
                if let index = pendingItems.firstIndex(where: { $0.id == pendingItem.id }) {
                    if let remaining = result.remaining, remaining > 0 {
                        // 部分领取 — 需要重新加载以获取更新后的数据
                        await loadPendingItems()
                    } else {
                        pendingItems.remove(at: index)
                    }
                }
                pendingCount = pendingItems.reduce(0) { $0 + $1.quantity }

                // 刷新背包
                await inventoryManager.loadInventory()

                return true
            } else {
                errorMessage = "领取失败: \(result.error ?? "未知错误")"
                return false
            }
        } catch {
            print("❌ [邮箱] 领取物品失败: \(error)")
            errorMessage = "领取失败: \(error.localizedDescription)"
            return false
        }
    }

    /// 全部领取
    /// - Returns: (成功领取数, 失败数)
    func claimAll() async -> (claimed: Int, failed: Int) {
        guard !pendingItems.isEmpty else { return (0, 0) }

        isClaiming = true
        errorMessage = nil
        var claimedCount = 0
        var failedCount = 0

        let inventoryManager = InventoryManager.shared

        // 确保有最新的物品定义和背包数据
        await inventoryManager.loadItemDefinitions()
        await inventoryManager.loadInventory()

        // 按顺序逐项领取
        for item in pendingItems {
            // 检查背包剩余容量
            let itemDef = inventoryManager.itemDefinitions.first { $0.id == item.itemId }
            if let def = itemDef {
                let addedWeight = def.weight * Double(item.quantity)
                let remainingCapacity = inventoryManager.maxWeight - inventoryManager.currentWeight
                if addedWeight > remainingCapacity {
                    errorMessage = "背包容量不足，已领取 \(claimedCount) 件，剩余 \(pendingItems.count - claimedCount) 件无法领取"
                    failedCount = pendingItems.count - claimedCount
                    break
                }
            }

            let success = await claimItem(item, quantity: item.quantity)
            if success {
                claimedCount += 1
            } else {
                failedCount = pendingItems.count - claimedCount
                break
            }
        }

        if failedCount == 0 {
            successMessage = "已领取全部 \(claimedCount) 件物品"
        }

        // 最终刷新
        await loadPendingItems()
        await inventoryManager.loadInventory()

        isClaiming = false
        return (claimedCount, failedCount)
    }

    /// 清除消息
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
