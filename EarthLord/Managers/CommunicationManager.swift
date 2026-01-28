//
//  CommunicationManager.swift
//  EarthLord
//
//  通讯管理器
//  负责处理聊天消息、实时通讯、附近玩家发现等功能
//

import Foundation
import Combine
import Supabase
import CoreLocation

/// 通讯管理器
@MainActor
class CommunicationManager: ObservableObject {

    // MARK: - 单例

    static let shared = CommunicationManager()

    // MARK: - 发布属性

    /// 当前频道消息列表
    @Published var messages: [ChatMessage] = []

    /// 当前选中的频道
    @Published var currentChannel: ChatChannel = .publicChannel

    /// 附近玩家列表
    @Published var nearbyPlayers: [NearbyPlayer] = []

    /// 未读消息数
    @Published var unreadCount: Int = 0

    /// 是否正在加载
    @Published var isLoading = false

    /// 是否已连接实时频道
    @Published var isConnected = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 当前通讯设备类型（旧版，保留兼容）
    @Published var currentDeviceType: CommunicationDeviceType = .advanced

    /// 通讯设备列表（新版）
    @Published private(set) var devices: [CommunicationDevice] = []

    /// 当前设备（新版）
    @Published private(set) var currentDevice: CommunicationDevice?

    // MARK: - 私有属性

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        AuthManager.shared.supabaseClient
    }

    /// 实时频道订阅
    private var realtimeChannel: RealtimeChannelV2?

    /// 消息发送限制（秒）
    private let rateLimitInterval: TimeInterval = 1.0
    private var lastMessageTime: Date?

    /// 最大消息长度
    private let maxMessageLength = 500

    /// 附近玩家搜索范围（米）
    private let nearbyRadius: Double = 100

    /// 定时器：更新在线状态
    private var presenceTimer: Timer?

    // MARK: - 初始化

    private init() {
        print("🔄 [通讯] CommunicationManager 初始化")
    }

    // MARK: - 实时通讯连接

    /// 连接实时通讯频道
    func connect() async {
        guard AuthManager.shared.currentUser != nil else {
            print("❌ [通讯] 连接失败：未登录")
            return
        }

        if isConnected {
            print("ℹ️ [通讯] 已连接，跳过")
            return
        }

        print("🔄 [通讯] 正在连接实时频道...")

        do {
            // 创建实时频道
            realtimeChannel = supabase.realtimeV2.channel("chat_messages")

            // 订阅消息插入事件
            let insertions = realtimeChannel!.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "chat_messages"
            )

            // 启动频道
            await realtimeChannel!.subscribe()

            isConnected = true
            print("✅ [通讯] 实时频道连接成功")

            // 监听新消息
            Task {
                for await insertion in insertions {
                    await handleNewMessage(insertion)
                }
            }

            // 启动在线状态更新
            startPresenceUpdates()

            // 加载历史消息
            await loadMessages(channel: currentChannel)

        } catch {
            print("❌ [通讯] 连接实时频道失败: \(error)")
            errorMessage = "连接失败: \(error.localizedDescription)"
            isConnected = false
        }
    }

    /// 断开实时通讯连接
    func disconnect() async {
        print("🔄 [通讯] 正在断开连接...")

        presenceTimer?.invalidate()
        presenceTimer = nil

        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }

        isConnected = false
        print("✅ [通讯] 已断开连接")
    }

    /// 处理新消息
    private func handleNewMessage(_ action: InsertAction) async {
        do {
            let message = try action.decodeRecord(as: ChatMessage.self, decoder: JSONDecoder.supabaseDecoder)

            // 只处理当前频道的消息
            if message.channel == currentChannel {
                // 避免重复
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                    messages.sort { $0.createdAt < $1.createdAt }
                    print("📩 [通讯] 收到新消息: \(message.content.prefix(20))...")
                }
            }

            // 更新未读数（非当前用户发送的消息）
            if let currentUserId = AuthManager.shared.currentUser?.id,
               message.senderId != currentUserId {
                unreadCount += 1
            }
        } catch {
            print("❌ [通讯] 解析新消息失败: \(error)")
        }
    }

    // MARK: - 发送消息

    /// 发送文字消息
    /// - Parameters:
    ///   - content: 消息内容
    ///   - channel: 目标频道
    /// - Returns: 发送结果
    func sendMessage(
        content: String,
        channel: ChatChannel = .publicChannel
    ) async -> Result<ChatMessage, Error> {
        print("🔄 [通讯] 开始发送消息...")

        // 1. 验证用户已登录
        guard let userId = AuthManager.shared.currentUser?.id else {
            print("❌ [通讯] 发送失败：未登录")
            return .failure(CommunicationError.notLoggedIn)
        }

        let username = AuthManager.shared.currentUser?.email?.components(separatedBy: "@").first

        // 2. 检查消息长度
        guard content.count <= maxMessageLength else {
            print("❌ [通讯] 发送失败：消息过长")
            return .failure(CommunicationError.messageTooLong)
        }

        // 3. 检查发送频率限制
        if let lastTime = lastMessageTime,
           Date().timeIntervalSince(lastTime) < rateLimitInterval {
            print("❌ [通讯] 发送失败：发送过于频繁")
            return .failure(CommunicationError.rateLimited)
        }

        // 4. 检查频道权限
        if channel == .publicChannel && !currentDeviceType.canUsePublicChannel {
            print("❌ [通讯] 发送失败：设备无法使用公共频道")
            return .failure(CommunicationError.channelRestricted)
        }

        // 5. 获取当前位置（用于附近频道）
        var latitude: Double?
        var longitude: Double?
        if channel == .nearby {
            if let userLocation = LocationManager.shared.userLocation {
                latitude = userLocation.latitude
                longitude = userLocation.longitude
            }
        }

        // 6. 插入消息到数据库
        do {
            let newMessage = NewChatMessage(
                senderId: userId.uuidString,
                senderUsername: username,
                channel: channel.rawValue,
                messageType: MessageType.text.rawValue,
                content: content,
                metadata: nil,
                senderLatitude: latitude,
                senderLongitude: longitude
            )

            let insertedMessages: [ChatMessage] = try await supabase
                .from("chat_messages")
                .insert(newMessage)
                .select()
                .execute()
                .value

            guard let insertedMessage = insertedMessages.first else {
                print("❌ [通讯] 发送失败：插入后无返回数据")
                return .failure(CommunicationError.databaseError("插入消息失败"))
            }

            lastMessageTime = Date()
            print("✅ [通讯] 消息发送成功: \(insertedMessage.id)")

            return .success(insertedMessage)
        } catch {
            print("❌ [通讯] 发送消息数据库错误: \(error)")
            return .failure(CommunicationError.databaseError(error.localizedDescription))
        }
    }

    /// 发送位置消息
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - channel: 目标频道
    /// - Returns: 发送结果
    func sendLocationMessage(
        latitude: Double,
        longitude: Double,
        channel: ChatChannel = .nearby
    ) async -> Result<ChatMessage, Error> {
        guard let userId = AuthManager.shared.currentUser?.id else {
            return .failure(CommunicationError.notLoggedIn)
        }

        let username = AuthManager.shared.currentUser?.email?.components(separatedBy: "@").first

        do {
            let metadata = MessageMetadata(
                latitude: latitude,
                longitude: longitude
            )

            let newMessage = NewChatMessage(
                senderId: userId.uuidString,
                senderUsername: username,
                channel: channel.rawValue,
                messageType: MessageType.location.rawValue,
                content: "分享了位置",
                metadata: metadata,
                senderLatitude: latitude,
                senderLongitude: longitude
            )

            let insertedMessages: [ChatMessage] = try await supabase
                .from("chat_messages")
                .insert(newMessage)
                .select()
                .execute()
                .value

            guard let insertedMessage = insertedMessages.first else {
                return .failure(CommunicationError.databaseError("插入消息失败"))
            }

            print("✅ [通讯] 位置消息发送成功")
            return .success(insertedMessage)
        } catch {
            print("❌ [通讯] 发送位置消息失败: \(error)")
            return .failure(CommunicationError.databaseError(error.localizedDescription))
        }
    }

    // MARK: - 加载消息

    /// 加载频道消息
    /// - Parameters:
    ///   - channel: 频道
    ///   - limit: 加载数量限制
    func loadMessages(channel: ChatChannel, limit: Int = 50) async {
        guard AuthManager.shared.currentUser != nil else {
            errorMessage = "请先登录"
            return
        }

        isLoading = true
        errorMessage = nil
        currentChannel = channel

        do {
            var query = supabase
                .from("chat_messages")
                .select()
                .eq("channel", value: channel.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)

            // 附近频道需要额外的位置过滤
            if channel == .nearby {
                // 服务端需要有 PostGIS 支持进行距离过滤
                // 这里先获取所有附近频道消息，客户端过滤
            }

            let loadedMessages: [ChatMessage] = try await query
                .execute()
                .value

            // 反转顺序（最新的在最后）
            messages = loadedMessages.reversed()
            print("🔄 [通讯] 加载了 \(messages.count) 条 \(channel.displayName) 消息")

        } catch {
            print("❌ [通讯] 加载消息失败: \(error)")
            errorMessage = "加载消息失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 加载更多历史消息
    /// - Parameter beforeDate: 加载此时间之前的消息
    func loadMoreMessages(beforeDate: Date) async {
        guard !isLoading else { return }

        isLoading = true

        do {
            let olderMessages: [ChatMessage] = try await supabase
                .from("chat_messages")
                .select()
                .eq("channel", value: currentChannel.rawValue)
                .lt("created_at", value: ISO8601DateFormatter().string(from: beforeDate))
                .order("created_at", ascending: false)
                .limit(30)
                .execute()
                .value

            // 插入到消息列表开头
            messages.insert(contentsOf: olderMessages.reversed(), at: 0)
            print("🔄 [通讯] 加载了 \(olderMessages.count) 条更早的消息")

        } catch {
            print("❌ [通讯] 加载更多消息失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 附近玩家

    /// 发现附近玩家
    func discoverNearbyPlayers() async {
        guard let userLocation = LocationManager.shared.userLocation else {
            print("⚠️ [通讯] 无法获取当前位置")
            return
        }

        let lat = userLocation.latitude
        let lng = userLocation.longitude

        print("🔄 [通讯] 搜索附近玩家 (范围: \(nearbyRadius)米)...")

        do {
            // 获取所有在线玩家，客户端进行距离过滤
            let players: [UserPresence] = try await supabase
                .from("user_presence")
                .select()
                .eq("is_online", value: true)
                .execute()
                .value

            // 计算精确距离并过滤
            var nearby: [NearbyPlayer] = []
            let currentUserId = AuthManager.shared.currentUser?.id
            let currentCLLocation = CLLocation(latitude: lat, longitude: lng)

            for player in players {
                // 排除自己
                if player.userId == currentUserId { continue }

                guard let playerLat = player.latitude,
                      let playerLng = player.longitude else { continue }

                let playerLocation = CLLocation(latitude: playerLat, longitude: playerLng)
                let distance = currentCLLocation.distance(from: playerLocation)

                if distance <= nearbyRadius {
                    nearby.append(NearbyPlayer(
                        id: player.userId,
                        username: player.username,
                        distance: distance,
                        lastActiveAt: player.lastSeenAt
                    ))
                }
            }

            // 按距离排序
            nearbyPlayers = nearby.sorted { $0.distance < $1.distance }
            print("✅ [通讯] 发现 \(nearbyPlayers.count) 个附近玩家")

        } catch {
            print("❌ [通讯] 搜索附近玩家失败: \(error)")
        }
    }

    // MARK: - 在线状态

    /// 启动在线状态更新
    private func startPresenceUpdates() {
        presenceTimer?.invalidate()
        presenceTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updatePresence()
            }
        }

        // 立即更新一次
        Task {
            await updatePresence()
        }
    }

    /// 更新用户在线状态
    private func updatePresence() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        var latitude: Double?
        var longitude: Double?

        if let userLocation = LocationManager.shared.userLocation {
            latitude = userLocation.latitude
            longitude = userLocation.longitude
        }

        let username = AuthManager.shared.currentUser?.email?.components(separatedBy: "@").first ?? "匿名"

        do {
            // 使用 upsert 更新或插入在线状态
            let presenceUpdate = UserPresenceUpsert(
                userId: userId.uuidString,
                username: username,
                isOnline: true,
                lastSeenAt: Date(),
                latitude: latitude,
                longitude: longitude
            )

            try await supabase
                .from("user_presence")
                .upsert(presenceUpdate)
                .execute()

        } catch {
            print("⚠️ [通讯] 更新在线状态失败: \(error)")
        }
    }

    /// 设置离线状态
    func setOffline() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        do {
            let offlineUpdate = UserPresenceOfflineUpdate(isOnline: false)

            try await supabase
                .from("user_presence")
                .update(offlineUpdate)
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("✅ [通讯] 已设置为离线状态")
        } catch {
            print("⚠️ [通讯] 设置离线状态失败: \(error)")
        }
    }

    // MARK: - 切换频道

    /// 切换聊天频道
    /// - Parameter channel: 目标频道
    func switchChannel(_ channel: ChatChannel) async {
        guard channel != currentChannel else { return }

        print("🔄 [通讯] 切换频道: \(currentChannel.displayName) -> \(channel.displayName)")
        currentChannel = channel
        messages = []
        await loadMessages(channel: channel)
    }

    // MARK: - 未读消息

    /// 清除未读消息计数
    func clearUnreadCount() {
        unreadCount = 0
    }

    /// 标记消息已读
    func markAsRead(_ messageId: UUID) async {
        do {
            try await supabase
                .from("chat_messages")
                .update(MessageReadUpdate(isRead: true))
                .eq("id", value: messageId.uuidString)
                .execute()
        } catch {
            print("⚠️ [通讯] 标记消息已读失败: \(error)")
        }
    }

    // MARK: - 辅助方法

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 检查是否可以发送消息到指定频道
    func canSendTo(channel: ChatChannel) -> Bool {
        switch channel {
        case .publicChannel:
            return currentDeviceType.canUsePublicChannel
        case .nearby:
            return LocationManager.shared.userLocation != nil
        case .territory, .trade:
            return true
        }
    }

    /// 获取频道可用状态描述
    func channelAvailabilityDescription(for channel: ChatChannel) -> String? {
        switch channel {
        case .publicChannel:
            if !currentDeviceType.canUsePublicChannel {
                return "需要高级通讯设备"
            }
        case .nearby:
            if LocationManager.shared.userLocation == nil {
                return "需要开启定位"
            }
        default:
            break
        }
        return nil
    }

    // MARK: - 设备管理（新版）

    /// 加载用户设备
    func loadDevices(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationDevice] = try await supabase
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            devices = response
            currentDevice = devices.first(where: { $0.isCurrent })

            if devices.isEmpty {
                await initializeDevices(userId: userId)
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 初始化用户设备
    func initializeDevices(userId: UUID) async {
        do {
            try await supabase.rpc("initialize_user_devices", params: ["p_user_id": userId.uuidString]).execute()
            await loadDevices(userId: userId)
        } catch {
            errorMessage = "初始化失败: \(error.localizedDescription)"
        }
    }

    /// 切换当前设备
    func switchDevice(userId: UUID, to deviceType: DeviceType) async {
        guard let device = devices.first(where: { $0.deviceType == deviceType }), device.isUnlocked else {
            errorMessage = "设备未解锁"
            return
        }

        if device.isCurrent { return }

        isLoading = true

        do {
            try await supabase.rpc("switch_current_device", params: [
                "p_user_id": userId.uuidString,
                "p_device_type": deviceType.rawValue
            ]).execute()

            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.deviceType == deviceType })
        } catch {
            errorMessage = "切换失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 解锁设备（由建造系统调用）
    func unlockDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            let updateData = DeviceUnlockUpdate(
                isUnlocked: true,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase
                .from("communication_devices")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }
        } catch {
            errorMessage = "解锁失败: \(error.localizedDescription)"
        }
    }

    /// 获取当前设备类型
    func getCurrentDeviceType() -> DeviceType {
        currentDevice?.deviceType ?? .walkieTalkie
    }

    /// 是否可以发送消息
    func canSendMessage() -> Bool {
        currentDevice?.deviceType.canSend ?? false
    }

    /// 获取当前通讯范围
    func getCurrentRange() -> Double {
        currentDevice?.deviceType.range ?? 3.0
    }

    /// 检查设备是否已解锁
    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }
}

// MARK: - 设备更新模型

private struct DeviceUnlockUpdate: Encodable {
    let isUnlocked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isUnlocked = "is_unlocked"
        case updatedAt = "updated_at"
    }
}

// MARK: - JSON Decoder Extension

extension JSONDecoder {
    static var supabaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // 尝试多种日期格式
            let formatters = [
                ISO8601DateFormatter(),
                { () -> DateFormatter in
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
                    return f
                }(),
                { () -> DateFormatter in
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                    return f
                }()
            ]

            for formatter in formatters {
                if let formatter = formatter as? ISO8601DateFormatter {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                } else if let formatter = formatter as? DateFormatter {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }
}
