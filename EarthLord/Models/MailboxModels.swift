//
//  MailboxModels.swift
//  EarthLord
//
//  待领取邮箱数据模型
//

import Foundation

/// 待领取物品
struct PendingItem: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let itemId: String
    let quantity: Int
    let source: String
    let sourceDisplay: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case source
        case sourceDisplay = "source_display"
        case createdAt = "created_at"
    }
}

/// 领取结果
struct ClaimResult: Codable {
    let success: Bool
    let itemId: String?
    let claimedQuantity: Int?
    let remaining: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case itemId = "item_id"
        case claimedQuantity = "claimed_quantity"
        case remaining
        case error
    }
}
