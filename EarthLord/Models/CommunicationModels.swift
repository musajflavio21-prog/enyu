//
//  CommunicationModels.swift
//  EarthLord
//
//  通讯系统数据模型
//  定义聊天消息、频道、通讯设备等
//

import Foundation

// MARK: - 聊天频道类型

/// 聊天频道枚举
enum ChatChannel: String, Codable, CaseIterable {
    case publicChannel = "public"       // 公共频道（全服）
    case nearby = "nearby"              // 附近频道（100米范围）
    case territory = "territory"        // 领地频道
    case trade = "trade"                // 交易频道

    /// 频道显示名称
    var displayName: String {
        switch self {
        case .publicChannel: return "公共频道"
        case .nearby: return "附近"
        case .territory: return "领地"
        case .trade: return "交易"
        }
    }

    /// 频道图标
    var iconName: String {
        switch self {
        case .publicChannel: return "globe"
        case .nearby: return "location.circle"
        case .territory: return "house.circle"
        case .trade: return "cart.circle"
        }
    }

    /// 频道描述
    var description: String {
        switch self {
        case .publicChannel: return "所有玩家都能看到"
        case .nearby: return "100米范围内玩家"
        case .territory: return "同一领地内玩家"
        case .trade: return "交易相关讨论"
        }
    }
}

// MARK: - 消息类型

/// 消息类型枚举
enum MessageType: String, Codable {
    case text = "text"              // 文字消息
    case system = "system"          // 系统消息
    case location = "location"      // 位置分享
    case trade = "trade"            // 交易链接
    case image = "image"            // 图片消息（预留）
    case voice = "voice"            // 语音消息（预留，PTT）
}

// MARK: - 聊天消息

/// 聊天消息结构体
struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let senderId: UUID
    let senderUsername: String?
    let channel: ChatChannel
    let messageType: MessageType
    let content: String
    let metadata: MessageMetadata?
    let createdAt: Date
    var isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case senderUsername = "sender_username"
        case channel
        case messageType = "message_type"
        case content
        case metadata
        case createdAt = "created_at"
        case isRead = "is_read"
    }

    /// 格式化时间
    var formattedTime: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(createdAt) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(createdAt) {
            formatter.dateFormat = "'昨天' HH:mm"
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
        }

        return formatter.string(from: createdAt)
    }

    /// 是否是自己发送的消息
    func isFromCurrentUser(currentUserId: UUID?) -> Bool {
        guard let currentUserId = currentUserId else { return false }
        return senderId == currentUserId
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 消息元数据

/// 消息元数据（用于扩展消息内容）
struct MessageMetadata: Codable {
    var latitude: Double?           // 位置分享-纬度
    var longitude: Double?          // 位置分享-经度
    var tradeOfferId: UUID?         // 交易链接-挂单ID
    var imageUrl: String?           // 图片消息-图片URL
    var voiceDuration: Int?         // 语音消息-时长（秒）
    var voiceUrl: String?           // 语音消息-音频URL

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case tradeOfferId = "trade_offer_id"
        case imageUrl = "image_url"
        case voiceDuration = "voice_duration"
        case voiceUrl = "voice_url"
    }
}

// MARK: - 新建消息请求

/// 新建消息请求（用于插入数据库）
struct NewChatMessage: Codable {
    let senderId: String
    let senderUsername: String?
    let channel: String
    let messageType: String
    let content: String
    let metadata: MessageMetadata?
    let senderLatitude: Double?
    let senderLongitude: Double?

    enum CodingKeys: String, CodingKey {
        case senderId = "sender_id"
        case senderUsername = "sender_username"
        case channel
        case messageType = "message_type"
        case content
        case metadata
        case senderLatitude = "sender_latitude"
        case senderLongitude = "sender_longitude"
    }
}

// MARK: - 附近玩家

/// 附近玩家信息
struct NearbyPlayer: Codable, Identifiable {
    let id: UUID
    let username: String?
    let distance: Double            // 距离（米）
    let lastActiveAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case distance
        case lastActiveAt = "last_active_at"
    }

    /// 格式化距离
    var formattedDistance: String {
        if distance < 1 {
            return "< 1米"
        } else if distance < 1000 {
            return "\(Int(distance))米"
        } else {
            return String(format: "%.1f公里", distance / 1000)
        }
    }
}

// MARK: - 通讯设备

/// 通讯设备类型
enum CommunicationDeviceType: String, Codable {
    case basic = "basic"            // 基础对讲机
    case advanced = "advanced"      // 高级对讲机
    case military = "military"      // 军用通讯设备
    case satellite = "satellite"    // 卫星通讯设备

    /// 设备显示名称
    var displayName: String {
        switch self {
        case .basic: return "基础对讲机"
        case .advanced: return "高级对讲机"
        case .military: return "军用通讯设备"
        case .satellite: return "卫星通讯设备"
        }
    }

    /// 通讯范围（米）
    var range: Double {
        switch self {
        case .basic: return 100
        case .advanced: return 500
        case .military: return 2000
        case .satellite: return Double.infinity  // 无限
        }
    }

    /// 是否可以使用公共频道
    var canUsePublicChannel: Bool {
        switch self {
        case .basic: return false
        case .advanced: return true
        case .military: return true
        case .satellite: return true
        }
    }

    /// 设备图标
    var iconName: String {
        switch self {
        case .basic: return "antenna.radiowaves.left.and.right"
        case .advanced: return "radio"
        case .military: return "antenna.radiowaves.left.and.right.circle"
        case .satellite: return "antenna.radiowaves.left.and.right.slash"
        }
    }
}

// MARK: - 通讯错误

/// 通讯错误枚举
enum CommunicationError: Error, LocalizedError {
    case notLoggedIn                    // 未登录
    case noDevice                       // 没有通讯设备
    case outOfRange                     // 超出通讯范围
    case channelRestricted              // 频道限制（设备等级不足）
    case messageTooLong                 // 消息过长
    case rateLimited                    // 发送过于频繁
    case networkError(String)           // 网络错误
    case databaseError(String)          // 数据库错误
    case realtimeError(String)          // 实时通讯错误
    case unknown(String)                // 未知错误

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "请先登录"
        case .noDevice:
            return "需要通讯设备才能发送消息"
        case .outOfRange:
            return "超出通讯范围"
        case .channelRestricted:
            return "当前设备无法使用此频道"
        case .messageTooLong:
            return "消息内容过长"
        case .rateLimited:
            return "发送过于频繁，请稍后再试"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        case .realtimeError(let message):
            return "实时通讯错误: \(message)"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}

// MARK: - 消息已读更新

/// 标记消息已读
struct MessageReadUpdate: Codable {
    let isRead: Bool

    enum CodingKeys: String, CodingKey {
        case isRead = "is_read"
    }
}

// MARK: - 用户在线状态

/// 用户在线状态
struct UserPresence: Codable {
    let userId: UUID
    let username: String?
    let isOnline: Bool
    let lastSeenAt: Date?
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case isOnline = "is_online"
        case lastSeenAt = "last_seen_at"
        case latitude
        case longitude
    }
}

/// 更新用户位置
struct UserLocationUpdate: Codable {
    let latitude: Double
    let longitude: Double
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case lastSeenAt = "last_seen_at"
    }
}

/// 用户在线状态 Upsert（用于插入或更新）
struct UserPresenceUpsert: Codable {
    let userId: String
    let username: String
    let isOnline: Bool
    let lastSeenAt: Date
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case isOnline = "is_online"
        case lastSeenAt = "last_seen_at"
        case latitude
        case longitude
    }
}

/// 用户离线更新
struct UserPresenceOfflineUpdate: Codable {
    let isOnline: Bool

    enum CodingKeys: String, CodingKey {
        case isOnline = "is_online"
    }
}
