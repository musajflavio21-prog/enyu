//
//  TradeManager.swift
//  EarthLord
//
//  交易管理器
//  负责处理玩家之间的异步挂单交易系统
//

import Foundation
import Combine
import Supabase

/// 交易管理器
@MainActor
class TradeManager: ObservableObject {

    // MARK: - 单例

    static let shared = TradeManager()

    // MARK: - 发布属性

    /// 我的挂单列表
    @Published var myOffers: [TradeOffer] = []

    /// 可接受的挂单列表（不包含自己的）
    @Published var availableOffers: [TradeOffer] = []

    /// 交易历史
    @Published var tradeHistory: [TradeHistory] = []

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        AuthManager.shared.supabaseClient
    }

    // MARK: - 初始化

    private init() {
        print("🔄 [交易] TradeManager 初始化")
    }

    // MARK: - 创建挂单

    /// 创建交易挂单
    /// - Parameters:
    ///   - offering: 提供的物品列表
    ///   - requesting: 需要的物品列表
    ///   - expiresInHours: 过期时间（小时）
    ///   - message: 附加消息（可选）
    /// - Returns: 创建结果
    func createOffer(
        offering: [TradeItem],
        requesting: [TradeItem],
        expiresInHours: Int = 24,
        message: String? = nil
    ) async -> Result<TradeOffer, Error> {
        print("🔄 [交易] 开始创建挂单...")

        // 1. 验证用户已登录
        guard let userId = AuthManager.shared.currentUser?.id else {
            print("❌ [交易] 创建挂单失败：未登录")
            return .failure(TradeError.notLoggedIn)
        }

        // 获取用户名
        let username = AuthManager.shared.currentUser?.email?.components(separatedBy: "@").first

        // 2. 检查背包库存是否足够
        let inventoryManager = InventoryManager.shared
        for tradeItem in offering {
            let availableQuantity = inventoryManager.getAvailableQuantity(itemId: tradeItem.itemId)
            if availableQuantity < tradeItem.quantity {
                print("❌ [交易] 创建挂单失败：物品 \(tradeItem.itemId) 数量不足（需要 \(tradeItem.quantity)，拥有 \(availableQuantity)）")
                return .failure(TradeError.insufficientItems)
            }
        }

        // 3. 从背包扣除物品（锁定）
        for tradeItem in offering {
            let success = await inventoryManager.deductItemForTrade(
                itemId: tradeItem.itemId,
                quantity: tradeItem.quantity
            )
            if !success {
                print("❌ [交易] 创建挂单失败：扣除物品 \(tradeItem.itemId) 失败")
                // 回滚已扣除的物品
                for rollbackItem in offering {
                    if rollbackItem.itemId == tradeItem.itemId { break }
                    _ = await inventoryManager.addItemForTrade(
                        itemId: rollbackItem.itemId,
                        quantity: rollbackItem.quantity
                    )
                }
                return .failure(TradeError.insufficientItems)
            }
        }

        // 4. 计算过期时间
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresInHours * 3600))

        // 5. 插入数据库
        do {
            let newOffer = NewTradeOffer(
                ownerId: userId.uuidString,
                ownerUsername: username,
                offeringItems: offering,
                requestingItems: requesting,
                status: TradeOfferStatus.active.rawValue,
                message: message,
                expiresAt: expiresAt
            )

            let insertedOffers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .insert(newOffer)
                .select()
                .execute()
                .value

            guard let insertedOffer = insertedOffers.first else {
                print("❌ [交易] 创建挂单失败：插入后无返回数据")
                // 回滚扣除的物品
                for tradeItem in offering {
                    _ = await inventoryManager.addItemForTrade(
                        itemId: tradeItem.itemId,
                        quantity: tradeItem.quantity
                    )
                }
                return .failure(TradeError.databaseError("插入挂单失败"))
            }

            print("✅ [交易] 挂单创建成功: \(insertedOffer.id)")

            // 刷新我的挂单列表
            await loadMyOffers()
            // 刷新背包（物品已扣除）
            await InventoryManager.shared.loadInventory()

            return .success(insertedOffer)
        } catch {
            print("❌ [交易] 创建挂单数据库错误: \(error)")
            // 回滚扣除的物品
            for tradeItem in offering {
                _ = await inventoryManager.addItemForTrade(
                    itemId: tradeItem.itemId,
                    quantity: tradeItem.quantity
                )
            }
            return .failure(TradeError.databaseError(error.localizedDescription))
        }
    }

    // MARK: - 接受交易

    /// 接受交易挂单
    /// - Parameter offerId: 挂单 ID
    /// - Returns: 交易历史结果
    /// - Note: 使用乐观锁机制防止并发接受：更新时检查状态仍为 active
    func acceptOffer(_ offerId: UUID) async -> Result<TradeHistory, Error> {
        print("🔄 [交易] 开始接受挂单: \(offerId)")

        // 1. 验证用户已登录
        guard let buyerId = AuthManager.shared.currentUser?.id else {
            print("❌ [交易] 接受挂单失败：未登录")
            return .failure(TradeError.notLoggedIn)
        }

        let buyerUsername = AuthManager.shared.currentUser?.email?.components(separatedBy: "@").first

        // 2. 查询挂单
        do {
            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("id", value: offerId.uuidString)
                .execute()
                .value

            guard let offer = offers.first else {
                print("❌ [交易] 接受挂单失败：找不到挂单")
                return .failure(TradeError.offerNotFound)
            }

            // 检查状态
            guard offer.status == .active else {
                print("❌ [交易] 接受挂单失败：挂单状态无效 (\(offer.status))")
                return .failure(TradeError.offerNotActive)
            }

            // 检查是否过期
            guard !offer.isExpired else {
                print("❌ [交易] 接受挂单失败：挂单已过期")
                return .failure(TradeError.offerExpired)
            }

            // 检查不是自己的挂单
            guard offer.ownerId != buyerId else {
                print("❌ [交易] 接受挂单失败：不能接受自己的挂单")
                return .failure(TradeError.cannotAcceptOwnOffer)
            }

            // 3. 检查接受者背包中 requesting 物品是否足够
            let inventoryManager = InventoryManager.shared
            for tradeItem in offer.requestingItems {
                let availableQuantity = inventoryManager.getAvailableQuantity(itemId: tradeItem.itemId)
                if availableQuantity < tradeItem.quantity {
                    print("❌ [交易] 接受挂单失败：物品 \(tradeItem.itemId) 数量不足")
                    return .failure(TradeError.insufficientItems)
                }
            }

            // 4. 【乐观锁】先尝试更新挂单状态为 completed（仅当状态为 active 时）
            // 这样如果有并发请求，只有一个会成功
            let completionUpdate = TradeOfferCompletionUpdate(
                status: TradeOfferStatus.completed.rawValue,
                completedAt: Date(),
                completedByUserId: buyerId.uuidString,
                completedByUsername: buyerUsername
            )

            let updatedOffers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .update(completionUpdate)
                .eq("id", value: offerId.uuidString)
                .eq("status", value: TradeOfferStatus.active.rawValue)  // 乐观锁条件
                .select()
                .execute()
                .value

            // 如果没有更新到任何记录，说明已被其他人接受或状态已改变
            guard updatedOffers.first != nil else {
                print("❌ [交易] 接受挂单失败：挂单已被其他人接受或状态已改变")
                return .failure(TradeError.offerNotActive)
            }

            // 5. 执行物品交换（此时挂单状态已锁定为 completed）
            // 5.1 从接受者背包扣除 requesting 物品
            var deductedItems: [TradeItem] = []
            for tradeItem in offer.requestingItems {
                let success = await inventoryManager.deductItemForTrade(
                    itemId: tradeItem.itemId,
                    quantity: tradeItem.quantity
                )
                if !success {
                    print("❌ [交易] 接受挂单失败：扣除物品失败，回滚中...")
                    // 回滚已扣除的物品
                    for rollbackItem in deductedItems {
                        _ = await inventoryManager.addItemForTrade(
                            itemId: rollbackItem.itemId,
                            quantity: rollbackItem.quantity
                        )
                    }
                    // 回滚挂单状态
                    try? await supabase
                        .from("trade_offers")
                        .update(["status": TradeOfferStatus.active.rawValue])
                        .eq("id", value: offerId.uuidString)
                        .execute()
                    return .failure(TradeError.insufficientItems)
                }
                deductedItems.append(tradeItem)
            }

            // 5.2 向接受者背包添加 offering 物品
            for tradeItem in offer.offeringItems {
                _ = await inventoryManager.addItemForTrade(
                    itemId: tradeItem.itemId,
                    quantity: tradeItem.quantity
                )
            }

            // 5.3 向发布者背包添加 requesting 物品
            for tradeItem in offer.requestingItems {
                _ = await inventoryManager.addItemForTradeToUser(
                    userId: offer.ownerId,
                    itemId: tradeItem.itemId,
                    quantity: tradeItem.quantity
                )
            }

            // 6. 创建交易历史记录
            let newHistory = NewTradeHistory(
                offerId: offerId.uuidString,
                sellerId: offer.ownerId.uuidString,
                sellerUsername: offer.ownerUsername,
                buyerId: buyerId.uuidString,
                buyerUsername: buyerUsername,
                itemsExchanged: TradeExchangeDetail(
                    offered: offer.offeringItems,
                    requested: offer.requestingItems
                )
            )

            let insertedHistories: [TradeHistory] = try await supabase
                .from("trade_history")
                .insert(newHistory)
                .select()
                .execute()
                .value

            guard let history = insertedHistories.first else {
                print("⚠️ [交易] 交易完成但创建历史记录失败")
                // 交易已完成，只是历史记录创建失败，不回滚
                await loadAvailableOffers()
                await loadTradeHistory()
                await InventoryManager.shared.loadInventory()
                return .failure(TradeError.databaseError("创建交易历史失败"))
            }

            print("✅ [交易] 交易完成: \(history.id)")

            // 刷新数据
            await loadAvailableOffers()
            await loadTradeHistory()
            // 刷新当前用户背包
            await InventoryManager.shared.loadInventory()

            return .success(history)
        } catch {
            print("❌ [交易] 接受挂单数据库错误: \(error)")
            return .failure(TradeError.databaseError(error.localizedDescription))
        }
    }

    // MARK: - 取消挂单

    /// 取消交易挂单
    /// - Parameter offerId: 挂单 ID
    /// - Returns: 取消结果
    func cancelOffer(_ offerId: UUID) async -> Result<Void, Error> {
        print("🔄 [交易] 开始取消挂单: \(offerId)")

        // 1. 验证用户已登录
        guard let userId = AuthManager.shared.currentUser?.id else {
            print("❌ [交易] 取消挂单失败：未登录")
            return .failure(TradeError.notLoggedIn)
        }

        // 2. 查询挂单
        do {
            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("id", value: offerId.uuidString)
                .execute()
                .value

            guard let offer = offers.first else {
                print("❌ [交易] 取消挂单失败：找不到挂单")
                return .failure(TradeError.offerNotFound)
            }

            // 验证是自己的挂单
            guard offer.ownerId == userId else {
                print("❌ [交易] 取消挂单失败：不是挂单所有者")
                return .failure(TradeError.notOfferOwner)
            }

            // 验证状态为 active
            guard offer.status == .active else {
                print("❌ [交易] 取消挂单失败：挂单状态无效 (\(offer.status))")
                return .failure(TradeError.offerNotActive)
            }

            // 3. 将 offering 物品退回发布者背包
            let inventoryManager = InventoryManager.shared
            for tradeItem in offer.offeringItems {
                _ = await inventoryManager.addItemForTrade(
                    itemId: tradeItem.itemId,
                    quantity: tradeItem.quantity
                )
            }

            // 4. 更新挂单状态为 cancelled
            let cancellationUpdate = TradeOfferCancellationUpdate(
                status: TradeOfferStatus.cancelled.rawValue
            )

            try await supabase
                .from("trade_offers")
                .update(cancellationUpdate)
                .eq("id", value: offerId.uuidString)
                .execute()

            print("✅ [交易] 挂单已取消: \(offerId)")

            // 刷新我的挂单列表
            await loadMyOffers()
            // 刷新背包（物品已退回）
            await InventoryManager.shared.loadInventory()

            return .success(())
        } catch {
            print("❌ [交易] 取消挂单数据库错误: \(error)")
            return .failure(TradeError.databaseError(error.localizedDescription))
        }
    }

    // MARK: - 加载数据

    /// 加载我的挂单
    func loadMyOffers() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "请先登录"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            myOffers = offers
            print("🔄 [交易] 加载了 \(offers.count) 个我的挂单")
        } catch {
            print("❌ [交易] 加载我的挂单失败: \(error)")
            errorMessage = "加载挂单失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 加载可接受的挂单（不包含自己的、状态为 active、未过期的）
    func loadAvailableOffers() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "请先登录"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("status", value: TradeOfferStatus.active.rawValue)
                .neq("owner_id", value: userId.uuidString)
                .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
                .order("created_at", ascending: false)
                .execute()
                .value

            availableOffers = offers
            print("🔄 [交易] 加载了 \(offers.count) 个可接受的挂单")
        } catch {
            print("❌ [交易] 加载可接受挂单失败: \(error)")
            errorMessage = "加载挂单失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 加载交易历史
    func loadTradeHistory() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "请先登录"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 查询自己作为卖家或买家的历史记录
            let histories: [TradeHistory] = try await supabase
                .from("trade_history")
                .select()
                .or("seller_id.eq.\(userId.uuidString),buyer_id.eq.\(userId.uuidString)")
                .order("completed_at", ascending: false)
                .execute()
                .value

            tradeHistory = histories
            print("🔄 [交易] 加载了 \(histories.count) 条交易历史")
        } catch {
            print("❌ [交易] 加载交易历史失败: \(error)")
            errorMessage = "加载交易历史失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 评价交易

    /// 评价交易
    /// - Parameters:
    ///   - historyId: 交易历史 ID
    ///   - rating: 评分（1-5）
    ///   - comment: 评论（可选）
    /// - Returns: 评价结果
    func rateTrade(
        _ historyId: UUID,
        rating: Int,
        comment: String? = nil
    ) async -> Result<Void, Error> {
        print("🔄 [交易] 开始评价交易: \(historyId)")

        // 1. 验证用户已登录
        guard let userId = AuthManager.shared.currentUser?.id else {
            print("❌ [交易] 评价失败：未登录")
            return .failure(TradeError.notLoggedIn)
        }

        // 2. 验证评分范围
        guard rating >= 1 && rating <= 5 else {
            print("❌ [交易] 评价失败：评分无效")
            return .failure(TradeError.invalidRating)
        }

        // 3. 查询交易历史
        do {
            let histories: [TradeHistory] = try await supabase
                .from("trade_history")
                .select()
                .eq("id", value: historyId.uuidString)
                .execute()
                .value

            guard let history = histories.first else {
                print("❌ [交易] 评价失败：找不到交易记录")
                return .failure(TradeError.offerNotFound)
            }

            // 4. 判断用户是卖家还是买家，并更新对应的评价
            if history.sellerId == userId {
                // 用户是卖家，更新卖家评价
                guard history.sellerRating == nil else {
                    print("❌ [交易] 评价失败：已经评价过")
                    return .failure(TradeError.alreadyRated)
                }

                let ratingUpdate = SellerRatingUpdate(
                    sellerRating: rating,
                    sellerComment: comment
                )

                try await supabase
                    .from("trade_history")
                    .update(ratingUpdate)
                    .eq("id", value: historyId.uuidString)
                    .execute()

            } else if history.buyerId == userId {
                // 用户是买家，更新买家评价
                guard history.buyerRating == nil else {
                    print("❌ [交易] 评价失败：已经评价过")
                    return .failure(TradeError.alreadyRated)
                }

                let ratingUpdate = BuyerRatingUpdate(
                    buyerRating: rating,
                    buyerComment: comment
                )

                try await supabase
                    .from("trade_history")
                    .update(ratingUpdate)
                    .eq("id", value: historyId.uuidString)
                    .execute()

            } else {
                print("❌ [交易] 评价失败：不是交易参与者")
                return .failure(TradeError.notOfferOwner)
            }

            print("✅ [交易] 评价成功: \(historyId)")

            // 刷新交易历史
            await loadTradeHistory()

            return .success(())
        } catch {
            print("❌ [交易] 评价数据库错误: \(error)")
            return .failure(TradeError.databaseError(error.localizedDescription))
        }
    }

    // MARK: - 刷新所有数据

    /// 刷新所有交易数据
    func refreshAll() async {
        await loadMyOffers()
        await loadAvailableOffers()
        await loadTradeHistory()
    }

    // MARK: - 辅助方法

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }
}
