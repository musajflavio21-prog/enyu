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

// MARK: - 设备类型（新版）

/// 设备类型枚举
enum DeviceType: String, Codable, CaseIterable {
    case radio = "radio"
    case walkieTalkie = "walkie_talkie"
    case campRadio = "camp_radio"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .radio: return "收音机"
        case .walkieTalkie: return "对讲机"
        case .campRadio: return "营地电台"
        case .satellite: return "卫星通讯"
        }
    }

    var iconName: String {
        switch self {
        case .radio: return "radio"
        case .walkieTalkie: return "phone.fill"
        case .campRadio: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .radio: return "只能接收信号，无法发送消息"
        case .walkieTalkie: return "可在3公里范围内通讯"
        case .campRadio: return "可在30公里范围内广播"
        case .satellite: return "可在100公里+范围内联络"
        }
    }

    var range: Double {
        switch self {
        case .radio: return Double.infinity
        case .walkieTalkie: return 3.0
        case .campRadio: return 30.0
        case .satellite: return 100.0
        }
    }

    var rangeText: String {
        switch self {
        case .radio: return "无限制（仅接收）"
        case .walkieTalkie: return "3 公里"
        case .campRadio: return "30 公里"
        case .satellite: return "100+ 公里"
        }
    }

    var canSend: Bool {
        self != .radio
    }

    var unlockRequirement: String {
        switch self {
        case .radio, .walkieTalkie: return "默认拥有"
        case .campRadio: return "需建造「营地电台」建筑"
        case .satellite: return "需建造「通讯塔」建筑"
        }
    }
}

// MARK: - 设备模型（新版）

/// 通讯设备结构体
struct CommunicationDevice: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let deviceType: DeviceType
    var deviceLevel: Int
    var isUnlocked: Bool
    var isCurrent: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceType = "device_type"
        case deviceLevel = "device_level"
        case isUnlocked = "is_unlocked"
        case isCurrent = "is_current"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 导航枚举

/// 通讯页面导航枚举
enum CommunicationSection: String, CaseIterable {
    case messages = "消息"
    case channels = "频道"
    case call = "呼叫"
    case devices = "设备"

    var iconName: String {
        switch self {
        case .messages: return "bell.fill"
        case .channels: return "dot.radiowaves.left.and.right"
        case .call: return "phone.fill"
        case .devices: return "gearshape.fill"
        }
    }
}

// MARK: - 频道类型（Day 33）

/// 频道类型枚举
enum ChannelType: String, Codable, CaseIterable {
    case official = "official"
    case publicChannel = "public"
    case walkie = "walkie"
    case camp = "camp"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .official: return "官方频道"
        case .publicChannel: return "公开频道"
        case .walkie: return "对讲频道"
        case .camp: return "营地频道"
        case .satellite: return "卫星频道"
        }
    }

    var iconName: String {
        switch self {
        case .official: return "star.circle.fill"
        case .publicChannel: return "globe"
        case .walkie: return "phone.fill"
        case .camp: return "tent.fill"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .official: return "官方公告和活动信息"
        case .publicChannel: return "所有人都可加入的公开频道"
        case .walkie: return "短距离对讲，范围3公里"
        case .camp: return "营地内部通讯"
        case .satellite: return "远距离卫星通讯"
        }
    }

    /// 用户可创建的频道类型（排除 official）
    static var creatableTypes: [ChannelType] {
        [.publicChannel, .walkie, .camp, .satellite]
    }

    /// 是否需要距离过滤（官方频道不需要）
    var requiresDistanceFilter: Bool {
        switch self {
        case .official:
            return false  // 官方公告无距离限制
        case .publicChannel, .walkie, .camp, .satellite:
            return true   // 其他频道需要距离过滤
        }
    }
}

// MARK: - 通讯频道

struct CommunicationChannel: Codable, Identifiable, Hashable {
    let id: UUID
    let creatorId: UUID
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    let isActive: Bool
    let memberCount: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive = "is_active"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CommunicationChannel, rhs: CommunicationChannel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 频道订阅

struct ChannelSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    var isMuted: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelId = "channel_id"
        case isMuted = "is_muted"
        case joinedAt = "joined_at"
    }
}

// MARK: - 已订阅频道（组合）

struct SubscribedChannel: Identifiable {
    let channel: CommunicationChannel
    let subscription: ChannelSubscription

    var id: UUID { channel.id }
}

// MARK: - 位置点模型（用于解析 PostGIS POINT）

struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double

    static func fromPostGIS(_ wkt: String) -> LocationPoint? {
        let pattern = #"POINT\(([0-9.-]+)\s+([0-9.-]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: wkt, range: NSRange(wkt.startIndex..., in: wkt)),
              let lonRange = Range(match.range(at: 1), in: wkt),
              let latRange = Range(match.range(at: 2), in: wkt),
              let longitude = Double(wkt[lonRange]),
              let latitude = Double(wkt[latRange]) else {
            return nil
        }
        return LocationPoint(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 频道消息元数据

struct ChannelMessageMetadata: Codable {
    let deviceType: String?
    let category: String?  // Day 36: 消息分类（用于官方频道）

    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
        case category
    }
}

// MARK: - 消息分类（Day 36）

/// 官方频道消息分类
enum MessageCategory: String, CaseIterable {
    case survival = "survival"     // 生存指南
    case news = "news"             // 末日新闻
    case mission = "mission"       // 任务发布
    case alert = "alert"           // 紧急警报

    var displayName: String {
        switch self {
        case .survival: return "生存指南"
        case .news: return "末日新闻"
        case .mission: return "任务发布"
        case .alert: return "紧急警报"
        }
    }

    var iconName: String {
        switch self {
        case .survival: return "heart.text.square"
        case .news: return "newspaper"
        case .mission: return "flag.fill"
        case .alert: return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .survival: return "green"
        case .news: return "blue"
        case .mission: return "orange"
        case .alert: return "red"
        }
    }
}

// MARK: - 频道摘要（Day 36）

/// 频道摘要信息（用于消息中心列表）
struct ChannelSummary: Identifiable {
    let channel: CommunicationChannel
    let latestMessage: ChannelMessage?
    let unreadCount: Int

    var id: UUID { channel.id }
}

// MARK: - 用户资料（Day 36）

/// 用户资料（用于呼号功能）
struct UserProfile: Codable, Identifiable {
    let id: UUID
    let username: String?
    let callsign: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case callsign
        case createdAt = "created_at"
    }
}

/// 呼号更新请求
struct CallsignUpdate: Codable {
    let callsign: String?

    enum CodingKeys: String, CodingKey {
        case callsign
    }
}

// MARK: - 频道消息模型

struct ChannelMessage: Codable, Identifiable {
    let messageId: UUID
    let channelId: UUID
    let senderId: UUID?
    let senderCallsign: String?
    let content: String
    let senderLocation: LocationPoint?
    let metadata: ChannelMessageMetadata?
    let createdAt: Date

    var id: UUID { messageId }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case channelId = "channel_id"
        case senderId = "sender_id"
        case senderCallsign = "sender_callsign"
        case content
        case senderLocation = "sender_location"
        case metadata
        case createdAt = "created_at"
    }

    // 自定义解码（处理 PostGIS POINT 格式 + 多种日期格式）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        messageId = try container.decode(UUID.self, forKey: .messageId)
        channelId = try container.decode(UUID.self, forKey: .channelId)
        senderId = try container.decodeIfPresent(UUID.self, forKey: .senderId)
        senderCallsign = try container.decodeIfPresent(String.self, forKey: .senderCallsign)
        content = try container.decode(String.self, forKey: .content)
        metadata = try container.decodeIfPresent(ChannelMessageMetadata.self, forKey: .metadata)

        // 解析 PostGIS POINT 格式的位置
        if let locationString = try container.decodeIfPresent(String.self, forKey: .senderLocation) {
            senderLocation = LocationPoint.fromPostGIS(locationString)
        } else {
            senderLocation = nil
        }

        // 多格式日期解析
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            if let date = ChannelMessage.parseDate(dateString) {
                createdAt = date
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .createdAt,
                    in: container,
                    debugDescription: "无法解析日期: \(dateString)"
                )
            }
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
    }

    // 日期解析辅助方法
    private static func parseDate(_ string: String) -> Date? {
        // ISO8601 格式
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: string) {
            return date
        }

        // 不带毫秒的 ISO8601
        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: string) {
            return date
        }

        // 自定义格式
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS+00:00",
            "yyyy-MM-dd'T'HH:mm:ss+00:00"
        ]

        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: string) {
                return date
            }
        }

        return nil
    }

    // 显示用计算属性：相对时间
    var timeAgo: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: createdAt, to: now)

        if let day = components.day, day > 0 {
            if day == 1 {
                return "昨天"
            } else if day < 7 {
                return "\(day)天前"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd"
                return formatter.string(from: createdAt)
            }
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)小时前"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)分钟前"
        } else {
            return "刚刚"
        }
    }

    // 格式化时间（HH:mm）
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: createdAt)
    }

    // 设备类型
    var deviceType: String? { metadata?.deviceType }

    /// 发送者设备类型（解析自 metadata）
    var senderDeviceType: DeviceType? {
        guard let deviceTypeString = metadata?.deviceType else { return nil }
        return DeviceType(rawValue: deviceTypeString)
    }
}
