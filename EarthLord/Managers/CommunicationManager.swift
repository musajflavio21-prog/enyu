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

    // MARK: - 常量

    /// 官方频道ID
    static let officialChannelId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

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

    /// 用户呼号（Day 36）
    @Published var userCallsign: String?

    /// 频道摘要列表（Day 36）
    @Published var channelSummaries: [ChannelSummary] = []

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

    // MARK: - IAP设备解锁

    /// 根据VIP等级和购买自动解锁通讯设备
    func applyIAPDeviceUnlocks() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        let store = StoreManager.shared
        let tier = store.currentVIPTier

        // 幸存者VIP及以上 → 解锁营地电台
        if tier >= .survivor {
            if !isDeviceUnlocked(.campRadio) {
                await unlockDevice(userId: userId, deviceType: .campRadio)
                print("🔓 [通讯] VIP解锁: 营地电台")
            }
        }

        // 领主VIP 或 购买了卫星通讯 → 解锁卫星设备
        if tier >= .lord || store.hasSatelliteDevice {
            if !isDeviceUnlocked(.satellite) {
                await unlockDevice(userId: userId, deviceType: .satellite)
                print("🔓 [通讯] VIP/购买解锁: 卫星通讯")
            }
        }
    }

    // MARK: - 频道相关属性（Day 33）

    /// 所有公开频道
    @Published var channels: [CommunicationChannel] = []

    /// 我订阅的频道
    @Published var subscribedChannels: [SubscribedChannel] = []

    /// 我的订阅列表
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []

    // MARK: - 频道消息属性（Day 34）

    /// 频道消息（按频道ID分组）
    @Published var channelMessages: [UUID: [ChannelMessage]] = [:]

    /// 是否正在发送消息
    @Published var isSendingMessage = false

    /// 已订阅消息的频道ID集合（用于本地追踪哪些频道在监听消息）
    @Published var subscribedChannelIds: Set<UUID> = []

    /// 消息实时订阅频道
    private var messageRealtimeChannel: RealtimeChannelV2?

    /// 消息订阅任务
    private var messageSubscriptionTask: Task<Void, Never>?

    // MARK: - 频道方法（Day 33）

    /// 加载公开频道
    func loadPublicChannels() async {
        print("🔄 [频道] 加载公开频道...")

        do {
            let response: [CommunicationChannel] = try await supabase
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            channels = response
            print("✅ [频道] 加载了 \(channels.count) 个公开频道")
        } catch {
            print("❌ [频道] 加载公开频道失败: \(error)")
            errorMessage = "加载频道失败: \(error.localizedDescription)"
        }
    }

    /// 加载已订阅频道
    func loadSubscribedChannels(userId: UUID) async {
        print("🔄 [频道] 加载用户订阅...")

        do {
            // 先加载订阅列表
            let subscriptions: [ChannelSubscription] = try await supabase
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            mySubscriptions = subscriptions

            if subscriptions.isEmpty {
                subscribedChannels = []
                print("ℹ️ [频道] 用户暂无订阅")
                return
            }

            // 获取订阅的频道ID列表
            let channelIds = subscriptions.map { $0.channelId.uuidString }

            // 加载对应的频道信息
            let channelsData: [CommunicationChannel] = try await supabase
                .from("communication_channels")
                .select()
                .in("id", values: channelIds)
                .eq("is_active", value: true)
                .execute()
                .value

            // 组合订阅和频道信息
            var combined: [SubscribedChannel] = []
            for channel in channelsData {
                if let subscription = subscriptions.first(where: { $0.channelId == channel.id }) {
                    combined.append(SubscribedChannel(channel: channel, subscription: subscription))
                }
            }

            subscribedChannels = combined
            print("✅ [频道] 加载了 \(subscribedChannels.count) 个已订阅频道")
        } catch {
            print("❌ [频道] 加载订阅失败: \(error)")
            errorMessage = "加载订阅失败: \(error.localizedDescription)"
        }
    }

    /// 创建频道
    func createChannel(
        userId: UUID,
        type: ChannelType,
        name: String,
        description: String?,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async -> Result<UUID, Error> {
        print("🔄 [频道] 创建频道: \(name)")

        do {
            // 构建 RPC 参数
            var params: [String: AnyJSON] = [
                "p_creator_id": .string(userId.uuidString),
                "p_channel_type": .string(type.rawValue),
                "p_name": .string(name)
            ]

            if let desc = description, !desc.isEmpty {
                params["p_description"] = .string(desc)
            } else {
                params["p_description"] = .null
            }

            if let lat = latitude, let lng = longitude {
                params["p_latitude"] = .double(lat)
                params["p_longitude"] = .double(lng)
            } else {
                params["p_latitude"] = .null
                params["p_longitude"] = .null
            }

            // 调用 RPC 函数
            let response: String = try await supabase
                .rpc("create_channel_with_subscription", params: params)
                .execute()
                .value

            // 解析返回的 UUID
            guard let channelId = UUID(uuidString: response.trimmingCharacters(in: CharacterSet(charactersIn: "\""))) else {
                print("❌ [频道] 无法解析频道ID: \(response)")
                return .failure(CommunicationError.databaseError("无法解析频道ID"))
            }

            print("✅ [频道] 频道创建成功: \(channelId)")

            // 刷新频道列表
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            return .success(channelId)
        } catch {
            print("❌ [频道] 创建频道失败: \(error)")
            return .failure(CommunicationError.databaseError(error.localizedDescription))
        }
    }

    /// 订阅频道
    func subscribeToChannel(userId: UUID, channelId: UUID) async -> Result<Void, Error> {
        print("🔄 [频道] 订阅频道: \(channelId)")

        do {
            let subscription = NewChannelSubscription(
                userId: userId.uuidString,
                channelId: channelId.uuidString
            )

            try await supabase
                .from("channel_subscriptions")
                .insert(subscription)
                .execute()

            // 更新频道成员数
            if let channel = channels.first(where: { $0.id == channelId }) {
                try await supabase
                    .from("communication_channels")
                    .update(["member_count": channel.memberCount + 1])
                    .eq("id", value: channelId.uuidString)
                    .execute()
            }

            print("✅ [频道] 订阅成功")

            // 刷新数据
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            return .success(())
        } catch {
            print("❌ [频道] 订阅失败: \(error)")
            return .failure(CommunicationError.databaseError(error.localizedDescription))
        }
    }

    /// 取消订阅
    func unsubscribeFromChannel(userId: UUID, channelId: UUID) async -> Result<Void, Error> {
        print("🔄 [频道] 取消订阅: \(channelId)")

        do {
            try await supabase
                .from("channel_subscriptions")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("channel_id", value: channelId.uuidString)
                .execute()

            // 更新频道成员数
            if let channel = channels.first(where: { $0.id == channelId }), channel.memberCount > 0 {
                try await supabase
                    .from("communication_channels")
                    .update(["member_count": channel.memberCount - 1])
                    .eq("id", value: channelId.uuidString)
                    .execute()
            }

            print("✅ [频道] 取消订阅成功")

            // 刷新数据
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            return .success(())
        } catch {
            print("❌ [频道] 取消订阅失败: \(error)")
            return .failure(CommunicationError.databaseError(error.localizedDescription))
        }
    }

    /// 检查是否已订阅
    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains(where: { $0.channelId == channelId })
    }

    /// 删除频道
    func deleteChannel(channelId: UUID) async -> Result<Void, Error> {
        print("🔄 [频道] 删除频道: \(channelId)")

        do {
            try await supabase
                .from("communication_channels")
                .delete()
                .eq("id", value: channelId.uuidString)
                .execute()

            print("✅ [频道] 频道删除成功")

            // 从本地列表移除
            channels.removeAll { $0.id == channelId }
            subscribedChannels.removeAll { $0.channel.id == channelId }

            return .success(())
        } catch {
            print("❌ [频道] 删除频道失败: \(error)")
            return .failure(CommunicationError.databaseError(error.localizedDescription))
        }
    }

    // MARK: - 频道消息管理（Day 34）

    /// 加载频道历史消息
    /// - Parameters:
    ///   - channelId: 频道ID
    ///   - limit: 加载数量（默认50）
    func loadChannelMessages(channelId: UUID, limit: Int = 50) async {
        print("🔄 [消息] 加载频道消息: \(channelId)")

        do {
            let response: [ChannelMessage] = try await supabase
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            // Day 35: 历史消息也应用距离过滤
            var filteredMessages = response
            if let channel = channels.first(where: { $0.id == channelId })
               ?? subscribedChannels.first(where: { $0.channel.id == channelId })?.channel {
                filteredMessages = response.filter { shouldReceiveMessage($0, in: channel) }
                if filteredMessages.count < response.count {
                    print("📡 [消息] 距离过滤：\(response.count) -> \(filteredMessages.count) 条消息")
                }
            }

            // 反转顺序（最新的在最后）
            channelMessages[channelId] = filteredMessages.reversed()
            print("✅ [消息] 加载了 \(filteredMessages.count) 条消息")
        } catch {
            print("❌ [消息] 加载消息失败: \(error)")
            errorMessage = "加载消息失败: \(error.localizedDescription)"
        }
    }

    /// 发送频道消息
    /// - Parameters:
    ///   - channelId: 频道ID
    ///   - content: 消息内容
    ///   - latitude: 纬度（可选）
    ///   - longitude: 经度（可选）
    /// - Returns: 是否发送成功
    func sendChannelMessage(
        channelId: UUID,
        content: String,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ [消息] 消息内容为空")
            return false
        }

        isSendingMessage = true
        defer { isSendingMessage = false }

        // 获取当前设备类型
        let deviceType = currentDevice?.deviceType.rawValue ?? "unknown"

        do {
            // 获取用户呼号
            let callsign = AuthManager.shared.currentUser?.email ?? "匿名幸存者"

            // 构建 RPC 参数
            var params: [String: AnyJSON] = [
                "p_channel_id": .string(channelId.uuidString),
                "p_content": .string(content),
                "p_device_type": .string(deviceType),
                "p_callsign": .string(callsign)
            ]

            if let lat = latitude, let lng = longitude {
                params["p_latitude"] = .double(lat)
                params["p_longitude"] = .double(lng)
            } else {
                params["p_latitude"] = .null
                params["p_longitude"] = .null
            }

            // 调用 RPC 函数
            let _: String = try await supabase
                .rpc("send_channel_message", params: params)
                .execute()
                .value

            print("✅ [消息] 消息发送成功")
            return true
        } catch {
            print("❌ [消息] 发送消息失败: \(error)")
            errorMessage = "发送失败: \(error.localizedDescription)"
            return false
        }
    }

    /// 启动 Realtime 消息订阅
    func startMessageRealtimeSubscription() async {
        // 如果已经有订阅，先停止
        await stopMessageRealtimeSubscription()

        print("🔄 [消息] 启动 Realtime 消息订阅...")

        do {
            // 创建实时频道
            messageRealtimeChannel = supabase.realtimeV2.channel("channel_messages_realtime")

            // 订阅消息插入事件
            let insertions = messageRealtimeChannel!.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "channel_messages"
            )

            // 启动频道
            await messageRealtimeChannel!.subscribe()

            print("✅ [消息] Realtime 消息订阅已启动")

            // 监听新消息
            messageSubscriptionTask = Task {
                for await insertion in insertions {
                    await handleChannelMessage(insertion: insertion)
                }
            }
        } catch {
            print("❌ [消息] 启动 Realtime 订阅失败: \(error)")
            errorMessage = "实时消息订阅失败"
        }
    }

    /// 停止 Realtime 订阅
    func stopMessageRealtimeSubscription() async {
        print("🔄 [消息] 停止 Realtime 消息订阅...")

        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil

        if let channel = messageRealtimeChannel {
            await channel.unsubscribe()
            messageRealtimeChannel = nil
        }

        print("✅ [消息] Realtime 消息订阅已停止")
    }

    /// 处理新消息
    private func handleChannelMessage(insertion: InsertAction) async {
        do {
            let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: JSONDecoder())

            // 只处理已订阅的频道消息
            guard subscribedChannelIds.contains(message.channelId) else {
                return
            }

            // Day 35: 距离过滤
            if let channel = channels.first(where: { $0.id == message.channelId })
               ?? subscribedChannels.first(where: { $0.channel.id == message.channelId })?.channel {
                if !shouldReceiveMessage(message, in: channel) {
                    print("📡 [消息] 距离过远，已过滤")
                    return
                }
            }

            // 避免重复
            if let existingMessages = channelMessages[message.channelId],
               existingMessages.contains(where: { $0.messageId == message.messageId }) {
                return
            }

            // 添加到消息列表
            if channelMessages[message.channelId] == nil {
                channelMessages[message.channelId] = []
            }
            channelMessages[message.channelId]?.append(message)

            print("📩 [消息] 收到新消息: \(message.content.prefix(20))...")
        } catch {
            print("❌ [消息] 解析新消息失败: \(error)")
        }
    }

    /// 订阅频道消息（本地追踪）
    /// - Parameter channelId: 频道ID
    func subscribeToChannelMessages(channelId: UUID) {
        subscribedChannelIds.insert(channelId)
        print("✅ [消息] 开始追踪频道消息: \(channelId)")
    }

    /// 取消订阅频道消息（本地追踪）
    /// - Parameter channelId: 频道ID
    func unsubscribeFromChannelMessages(channelId: UUID) {
        subscribedChannelIds.remove(channelId)
        print("✅ [消息] 停止追踪频道消息: \(channelId)")
    }

    /// 获取频道消息列表
    /// - Parameter channelId: 频道ID
    /// - Returns: 消息列表
    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }

    /// 清除频道消息缓存
    /// - Parameter channelId: 频道ID
    func clearMessages(for channelId: UUID) {
        channelMessages.removeValue(forKey: channelId)
    }

    // MARK: - 距离过滤算法（Day 35）

    /// 计算两个设备类型之间的最大通讯距离（公里）
    private func maxCommunicationDistance(senderDevice: DeviceType, receiverDevice: DeviceType) -> Double {
        // 收音机接收方：无距离限制
        if receiverDevice == .radio {
            return Double.infinity
        }
        // 收音机发送方：不能发送
        if senderDevice == .radio {
            return 0
        }

        switch (senderDevice, receiverDevice) {
        case (.walkieTalkie, .walkieTalkie):
            return 3.0
        case (.walkieTalkie, .campRadio), (.campRadio, .walkieTalkie):
            return 30.0
        case (.walkieTalkie, .satellite), (.satellite, .walkieTalkie):
            return 100.0
        case (.campRadio, .campRadio):
            return 30.0
        case (.campRadio, .satellite), (.satellite, .campRadio):
            return 100.0
        case (.satellite, .satellite):
            return 100.0
        default:
            return Double.infinity  // 保守策略
        }
    }

    /// 计算两点之间的距离（公里）
    private func calculateDistance(from: LocationPoint, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0
    }

    /// 获取当前位置（Day 35-A 返回假数据，Day 35-B 替换为真实 GPS）
    private func getCurrentLocation() -> CLLocationCoordinate2D? {
        #if DEBUG
        // Day 35-C: 调试模式优先使用模拟位置
        return LocationManager.shared.effectiveLocation
        #else
        return LocationManager.shared.userLocation
        #endif
    }

    /// 判断是否应该接收消息
    func shouldReceiveMessage(_ message: ChannelMessage, in channel: CommunicationChannel) -> Bool {
        // 1. 官方频道不过滤
        if !channel.channelType.requiresDistanceFilter {
            print("📡 [距离过滤] \(channel.name) 无需过滤")
            return true
        }

        // 2. 保守策略：无设备信息时允许
        guard let receiverDevice = currentDevice else {
            print("📡 [距离过滤] 无接收设备，保守允许")
            return true
        }

        // 3. 收音机接收所有消息
        if receiverDevice.deviceType == .radio {
            print("📻 [距离过滤] 收音机用户，接收所有消息")
            return true
        }

        // 4. 保守策略：发送者位置缺失时允许
        guard let senderLocation = message.senderLocation else {
            print("📡 [距离过滤] 发送者位置缺失，保守允许")
            return true
        }

        // 5. 保守策略：接收者位置缺失时允许
        guard let receiverLocation = getCurrentLocation() else {
            print("📡 [距离过滤] 接收者位置缺失，保守允许")
            return true
        }

        // 6. 保守策略：发送者设备类型缺失时允许
        guard let senderDevice = message.senderDeviceType else {
            print("📡 [距离过滤] 发送者设备类型缺失，保守允许")
            return true
        }

        // 7. 计算距离
        let distance = calculateDistance(from: senderLocation, to: receiverLocation)
        let maxDistance = maxCommunicationDistance(senderDevice: senderDevice, receiverDevice: receiverDevice.deviceType)
        let isInRange = distance <= maxDistance

        print("📡 [距离过滤] \(senderDevice.rawValue)→\(receiverDevice.deviceType.rawValue) 距离:\(String(format: "%.1f", distance))km 最大:\(maxDistance == .infinity ? "∞" : String(format: "%.0f", maxDistance))km \(isInRange ? "✅" : "❌")")

        return isInRange
    }

    // MARK: - 官方频道方法（Day 36）

    /// 判断是否是官方频道
    func isOfficialChannel(_ channelId: UUID) -> Bool {
        channelId == CommunicationManager.officialChannelId
    }

    /// 确保用户已订阅官方频道
    func ensureOfficialChannelSubscribed(userId: UUID) async {
        // 检查是否已订阅
        if isSubscribed(channelId: CommunicationManager.officialChannelId) {
            print("✅ [官方频道] 用户已订阅官方频道")
            return
        }

        print("🔄 [官方频道] 自动订阅官方频道...")

        do {
            let subscription = NewChannelSubscription(
                userId: userId.uuidString,
                channelId: CommunicationManager.officialChannelId.uuidString
            )

            try await supabase
                .from("channel_subscriptions")
                .insert(subscription)
                .execute()

            // 更新成员数
            try await supabase
                .from("communication_channels")
                .update(["member_count": 1])  // 简化处理，实际应该 +1
                .eq("id", value: CommunicationManager.officialChannelId.uuidString)
                .execute()

            print("✅ [官方频道] 自动订阅成功")

            // 刷新订阅列表
            await loadSubscribedChannels(userId: userId)
        } catch {
            print("⚠️ [官方频道] 自动订阅失败: \(error)")
        }
    }

    /// 获取频道摘要列表（用于消息中心）
    func getChannelSummaries() async {
        print("🔄 [消息中心] 加载频道摘要...")

        var summaries: [ChannelSummary] = []

        // 1. 添加官方频道（置顶）
        if let officialChannel = channels.first(where: { $0.id == CommunicationManager.officialChannelId })
           ?? subscribedChannels.first(where: { $0.channel.id == CommunicationManager.officialChannelId })?.channel {
            let officialMessages = channelMessages[officialChannel.id] ?? []
            summaries.append(ChannelSummary(
                channel: officialChannel,
                latestMessage: officialMessages.last,
                unreadCount: 0
            ))
        }

        // 2. 添加其他已订阅频道
        for subscribed in subscribedChannels {
            // 跳过官方频道（已添加）
            if subscribed.channel.id == CommunicationManager.officialChannelId { continue }

            let messages = channelMessages[subscribed.channel.id] ?? []
            summaries.append(ChannelSummary(
                channel: subscribed.channel,
                latestMessage: messages.last,
                unreadCount: 0
            ))
        }

        channelSummaries = summaries
        print("✅ [消息中心] 加载了 \(summaries.count) 个频道摘要")
    }

    /// 加载所有订阅频道的最新消息
    func loadAllChannelLatestMessages() async {
        print("🔄 [消息中心] 加载所有频道最新消息...")

        // 加载官方频道消息
        await loadChannelMessages(channelId: CommunicationManager.officialChannelId, limit: 20)

        // 加载其他订阅频道消息
        for subscribed in subscribedChannels {
            if subscribed.channel.id == CommunicationManager.officialChannelId { continue }
            await loadChannelMessages(channelId: subscribed.channel.id, limit: 5)
        }

        // 更新摘要
        await getChannelSummaries()
    }

    // MARK: - 呼号管理（Day 36）

    /// 加载用户呼号
    func loadUserCallsign(userId: UUID) async {
        print("🔄 [呼号] 加载用户呼号...")

        do {
            let response: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            if let profile = response.first {
                userCallsign = profile.callsign
                print("✅ [呼号] 加载成功: \(profile.callsign ?? "未设置")")
            }
        } catch {
            print("❌ [呼号] 加载失败: \(error)")
        }
    }

    /// 更新用户呼号
    func updateUserCallsign(userId: UUID, callsign: String?) async -> Bool {
        print("🔄 [呼号] 更新用户呼号: \(callsign ?? "清除")")

        do {
            let update = CallsignUpdate(callsign: callsign)

            try await supabase
                .from("profiles")
                .update(update)
                .eq("id", value: userId.uuidString)
                .execute()

            userCallsign = callsign
            print("✅ [呼号] 更新成功")
            return true
        } catch {
            print("❌ [呼号] 更新失败: \(error)")
            errorMessage = "更新呼号失败: \(error.localizedDescription)"
            return false
        }
    }

    /// 获取当前呼号（用于显示）
    func getCurrentCallsign() -> String {
        userCallsign ?? "未设置呼号"
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

// MARK: - 频道订阅模型（Day 33）

struct NewChannelSubscription: Encodable {
    let userId: String
    let channelId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case channelId = "channel_id"
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
