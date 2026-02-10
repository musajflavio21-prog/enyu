//
//  StoreManager.swift
//  EarthLord
//
//  内购管理器
//  负责StoreKit 2产品加载、购买、恢复、权益管理
//

import Foundation
import Combine
import StoreKit
import Supabase

/// 内购管理器
@MainActor
class StoreManager: ObservableObject {

    // MARK: - 单例

    static let shared = StoreManager()

    // MARK: - 发布属性

    /// StoreKit 产品列表
    @Published var products: [Product] = []

    /// 订阅产品
    @Published var subscriptions: [Product] = []

    /// 消耗品产品
    @Published var consumables: [Product] = []

    /// 非消耗品产品
    @Published var nonConsumables: [Product] = []

    /// 物资包产品
    @Published var resourcePacks: [Product] = []

    /// 用户权益
    @Published var entitlements: UserEntitlements = .defaultEntitlements

    /// 是否正在加载产品
    @Published var isLoadingProducts = false

    /// 是否正在购买
    @Published var isPurchasing = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 购买成功提示
    @Published var purchaseSuccessMessage: String?

    // MARK: - 计算属性

    /// 当前VIP等级
    var currentVIPTier: VIPTier {
        entitlements.currentVIPTier
    }

    /// 末日币余额
    var coinBalance: Int {
        entitlements.coinBalance
    }

    /// 最大领地数量
    var maxTerritoryCount: Int {
        currentVIPTier.maxTerritoryCount + entitlements.extraTerritorySlots
    }

    /// 最大背包重量
    var maxBackpackWeight: Double {
        currentVIPTier.baseMaxWeight + Double(entitlements.extraBackpackKg)
    }

    /// 最大背包容量
    var maxBackpackVolume: Double {
        currentVIPTier.baseMaxVolume
    }

    /// 建造速度倍率
    var buildSpeedMultiplier: Double {
        currentVIPTier.buildSpeedMultiplier
    }

    /// 是否有卫星通讯
    var hasSatelliteDevice: Bool {
        entitlements.hasSatelliteDevice || currentVIPTier >= .survivor
    }

    /// 是否有高级雷达
    var hasPremiumRadar: Bool {
        entitlements.hasPremiumRadar
    }

    /// VIP是否有效
    var isVIPActive: Bool {
        entitlements.isVIPActive
    }

    // MARK: - 私有属性

    /// Supabase客户端
    private var supabase: SupabaseClient {
        AuthManager.shared.supabaseClient
    }

    /// 交易监听任务
    private var transactionListener: Task<Void, Error>?

    // MARK: - 初始化

    private init() {
        print("🛒 [商店] StoreManager 初始化")
        startTransactionListener()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - 产品加载

    /// 加载所有产品
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        errorMessage = nil

        do {
            let productIds = StoreProductID.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: Set(productIds))

            products = storeProducts.sorted { $0.price < $1.price }
            subscriptions = storeProducts.filter { product in
                StoreProductID(rawValue: product.id)?.productType == .subscription
            }.sorted { $0.price < $1.price }
            consumables = storeProducts.filter { product in
                guard let pid = StoreProductID(rawValue: product.id) else { return false }
                return pid.productType == .consumable && !pid.isResourcePack
            }.sorted { $0.price < $1.price }
            resourcePacks = storeProducts.filter { product in
                StoreProductID(rawValue: product.id)?.isResourcePack == true
            }.sorted { $0.price < $1.price }
            nonConsumables = storeProducts.filter { product in
                StoreProductID(rawValue: product.id)?.productType == .nonConsumable
            }.sorted { $0.price < $1.price }

            print("🛒 [商店] 加载了 \(storeProducts.count) 个产品")
            print("🛒 [商店] 订阅: \(subscriptions.count), 消耗品: \(consumables.count), 物资包: \(resourcePacks.count), 非消耗品: \(nonConsumables.count)")
        } catch {
            print("❌ [商店] 加载产品失败: \(error)")
            errorMessage = "加载商品失败，请稍后重试"
        }

        isLoadingProducts = false
    }

    // MARK: - 权益加载

    /// 从服务端加载用户权益
    func loadEntitlements() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        do {
            let result: UserEntitlements = try await supabase
                .from("user_entitlements")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value

            entitlements = result
            print("🛒 [商店] 加载权益: VIP=\(result.currentVIPTier.displayName), 币=\(result.coinBalance)")
        } catch {
            print("❌ [商店] 加载权益失败: \(error)")
            // 如果记录不存在，使用默认值
            entitlements = .defaultEntitlements
        }
    }

    // MARK: - 购买

    /// 购买产品
    /// - Parameter product: StoreKit产品
    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil
        purchaseSuccessMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // 服务端验证
                await validateWithServer(transaction: transaction, product: product)

                // 完成交易
                await transaction.finish()

                // 重新加载权益
                await loadEntitlements()

                let productId = StoreProductID(rawValue: product.id)

                // 如果是物资包，刷新邮箱（物资已由服务端放入pending_items）
                if let pid = productId, pid.isResourcePack {
                    await MailboxManager.shared.loadPendingItems()
                    purchaseSuccessMessage = "购买成功！物资已发送到邮箱，请前往领取"
                } else {
                    purchaseSuccessMessage = "成功购买 \(productId?.displayName ?? product.displayName)"
                }
                print("🛒 [商店] 购买成功: \(product.id)")

            case .userCancelled:
                print("🛒 [商店] 用户取消购买")

            case .pending:
                print("🛒 [商店] 购买待处理")
                errorMessage = "购买正在处理中，请稍候"

            @unknown default:
                print("🛒 [商店] 未知购买结果")
            }
        } catch {
            print("❌ [商店] 购买失败: \(error)")
            errorMessage = "购买失败: \(error.localizedDescription)"
        }

        isPurchasing = false
    }

    // MARK: - 恢复购买

    /// 恢复购买
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            print("🛒 [商店] 恢复购买完成")

            // 检查当前订阅状态
            for await result in Transaction.currentEntitlements {
                if let transaction = try? checkVerified(result) {
                    await validateWithServer(transaction: transaction, product: nil)
                    await transaction.finish()
                }
            }

            // 重新加载权益
            await loadEntitlements()
            purchaseSuccessMessage = "恢复购买完成"
        } catch {
            print("❌ [商店] 恢复购买失败: \(error)")
            errorMessage = "恢复购买失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 末日币操作

    /// 花费末日币
    /// - Parameters:
    ///   - amount: 花费数量
    ///   - reason: 花费原因
    ///   - referenceId: 关联ID
    /// - Returns: 是否成功
    func spendCoins(amount: Int, reason: String, referenceId: String? = nil) async -> Bool {
        guard let userId = AuthManager.shared.currentUser?.id else { return false }
        guard entitlements.coinBalance >= amount else {
            errorMessage = "末日币不足"
            return false
        }

        do {
            let params: [String: String] = [
                "p_user_id": userId.uuidString,
                "p_amount": String(amount),
                "p_reason": reason,
                "p_reference_id": referenceId ?? ""
            ]
            let newBalance: Int = try await supabase
                .rpc("spend_coins", params: params)
                .execute()
                .value

            entitlements.coinBalance = newBalance
            print("🛒 [商店] 花费 \(amount) 末日币, 剩余 \(newBalance)")
            return true
        } catch {
            print("❌ [商店] 花费末日币失败: \(error)")
            errorMessage = "操作失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 私有方法

    /// 启动交易监听
    private func startTransactionListener() {
        transactionListener = Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? self.checkVerified(result) {
                    await self.validateWithServer(transaction: transaction, product: nil)
                    await transaction.finish()
                    await self.loadEntitlements()
                }
            }
        }
    }

    /// 验证交易签名
    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    /// 服务端验证
    private func validateWithServer(transaction: Transaction, product: Product?) async {
        guard AuthManager.shared.currentUser?.id != nil else { return }

        let productId = StoreProductID(rawValue: transaction.productID)
        let dateFormatter = ISO8601DateFormatter()

        let requestBody = ValidatePurchaseRequest(
            productId: transaction.productID,
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            purchaseDate: dateFormatter.string(from: transaction.purchaseDate),
            expiresDate: transaction.expirationDate.map { dateFormatter.string(from: $0) },
            productType: productId?.productType.rawValue ?? "consumable",
            jwsRepresentation: nil
        )

        do {
            let response: ValidatePurchaseResponse = try await supabase.functions
                .invoke(
                    "validate-purchase",
                    options: .init(body: requestBody)
                )

            if let error = response.error {
                print("❌ [商店] 服务端验证错误: \(error)")
            } else {
                print("🛒 [商店] 服务端验证成功: \(response.message ?? "OK")")
            }
        } catch {
            print("❌ [商店] 服务端验证失败: \(error)")
        }
    }
}
