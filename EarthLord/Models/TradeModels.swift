//
//  TradeModels.swift
//  EarthLord
//
//  交易系统数据模型
//  定义交易挂单、交易历史、交易状态等
//

import Foundation

// MARK: - 交易挂单状态

/// 交易挂单状态枚举
enum TradeOfferStatus: String, Codable {
    case active = "active"          // 进行中
    case completed = "completed"    // 已完成
    case cancelled = "cancelled"    // 已取消
    case expired = "expired"        // 已过期

    /// 状态显示名称
    var displayName: String {
        switch self {
        case .active: return "进行中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .expired: return "已过期"
        }
    }

    /// 状态颜色名称
    var colorName: String {
        switch self {
        case .active: return "green"
        case .completed: return "blue"
        case .cancelled: return "gray"
        case .expired: return "orange"
        }
    }
}

// MARK: - 交易物品

/// 交易物品（用于 JSON 存储）
struct TradeItem: Codable, Equatable {
    let itemId: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
    }
}

// MARK: - 交易挂单

/// 交易挂单结构体
struct TradeOffer: Codable, Identifiable {
    let id: UUID
    let ownerId: UUID
    let ownerUsername: String?
    let offeringItems: [TradeItem]      // 提供的物品
    let requestingItems: [TradeItem]    // 需要的物品
    var status: TradeOfferStatus
    let message: String?
    let createdAt: Date
    let expiresAt: Date
    var completedAt: Date?
    var completedByUserId: UUID?
    var completedByUsername: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status
        case message
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case completedAt = "completed_at"
        case completedByUserId = "completed_by_user_id"
        case completedByUsername = "completed_by_username"
    }

    /// 是否已过期
    var isExpired: Bool {
        return Date() > expiresAt
    }

    /// 剩余时间（秒）
    var remainingTimeSeconds: TimeInterval {
        return max(0, expiresAt.timeIntervalSince(Date()))
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        let remaining = Int(remainingTimeSeconds)
        if remaining <= 0 { return "已过期" }

        if remaining >= 86400 {
            let days = remaining / 86400
            let hours = (remaining % 86400) / 3600
            return "\(days)天\(hours)小时"
        } else if remaining >= 3600 {
            let hours = remaining / 3600
            let minutes = (remaining % 3600) / 60
            return "\(hours)小时\(minutes)分"
        } else if remaining >= 60 {
            let minutes = remaining / 60
            return "\(minutes)分钟"
        } else {
            return "\(remaining)秒"
        }
    }
}

// MARK: - 新建交易挂单请求

/// 新建交易挂单请求（用于插入数据库）
struct NewTradeOffer: Codable {
    let ownerId: String
    let ownerUsername: String?
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]
    let status: String
    let message: String?
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status
        case message
        case expiresAt = "expires_at"
    }
}

// MARK: - 交易挂单更新

/// 完成交易更新
struct TradeOfferCompletionUpdate: Codable {
    let status: String
    let completedAt: Date
    let completedByUserId: String
    let completedByUsername: String?

    enum CodingKeys: String, CodingKey {
        case status
        case completedAt = "completed_at"
        case completedByUserId = "completed_by_user_id"
        case completedByUsername = "completed_by_username"
    }
}

/// 取消交易更新
struct TradeOfferCancellationUpdate: Codable {
    let status: String

    enum CodingKeys: String, CodingKey {
        case status
    }
}

// MARK: - 交易交换详情

/// 交易交换详情（历史记录用）
struct TradeExchangeDetail: Codable {
    let offered: [TradeItem]
    let requested: [TradeItem]
}

// MARK: - 交易历史

/// 交易历史记录结构体
struct TradeHistory: Codable, Identifiable {
    let id: UUID
    let offerId: UUID?
    let sellerId: UUID
    let sellerUsername: String?
    let buyerId: UUID
    let buyerUsername: String?
    let itemsExchanged: TradeExchangeDetail
    let completedAt: Date
    var sellerRating: Int?
    var buyerRating: Int?
    var sellerComment: String?
    var buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case sellerUsername = "seller_username"
        case buyerId = "buyer_id"
        case buyerUsername = "buyer_username"
        case itemsExchanged = "items_exchanged"
        case completedAt = "completed_at"
        case sellerRating = "seller_rating"
        case buyerRating = "buyer_rating"
        case sellerComment = "seller_comment"
        case buyerComment = "buyer_comment"
    }

    /// 格式化完成时间
    var formattedCompletedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: completedAt)
    }
}

// MARK: - 新建交易历史请求

/// 新建交易历史请求（用于插入数据库）
struct NewTradeHistory: Codable {
    let offerId: String?
    let sellerId: String
    let sellerUsername: String?
    let buyerId: String
    let buyerUsername: String?
    let itemsExchanged: TradeExchangeDetail

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case sellerUsername = "seller_username"
        case buyerId = "buyer_id"
        case buyerUsername = "buyer_username"
        case itemsExchanged = "items_exchanged"
    }
}

// MARK: - 交易评价更新

/// 卖家评价更新
struct SellerRatingUpdate: Codable {
    let sellerRating: Int
    let sellerComment: String?

    enum CodingKeys: String, CodingKey {
        case sellerRating = "seller_rating"
        case sellerComment = "seller_comment"
    }
}

/// 买家评价更新
struct BuyerRatingUpdate: Codable {
    let buyerRating: Int
    let buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case buyerRating = "buyer_rating"
        case buyerComment = "buyer_comment"
    }
}

// MARK: - 交易错误

/// 交易错误枚举
enum TradeError: Error, LocalizedError {
    case notLoggedIn                    // 未登录
    case offerNotFound                  // 找不到挂单
    case offerExpired                   // 挂单已过期
    case offerNotActive                 // 挂单状态无效
    case cannotAcceptOwnOffer           // 不能接受自己的挂单
    case insufficientItems              // 物品不足
    case notOfferOwner                  // 不是挂单所有者
    case alreadyRated                   // 已经评价过
    case invalidRating                  // 无效评价（必须1-5）
    case databaseError(String)          // 数据库错误
    case unknown(String)                // 未知错误

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "请先登录"
        case .offerNotFound:
            return "找不到该交易挂单"
        case .offerExpired:
            return "该交易挂单已过期"
        case .offerNotActive:
            return "该交易挂单已不可用"
        case .cannotAcceptOwnOffer:
            return "不能接受自己发布的挂单"
        case .insufficientItems:
            return "物品数量不足"
        case .notOfferOwner:
            return "只能操作自己发布的挂单"
        case .alreadyRated:
            return "您已经评价过此交易"
        case .invalidRating:
            return "评价必须在1-5之间"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}
