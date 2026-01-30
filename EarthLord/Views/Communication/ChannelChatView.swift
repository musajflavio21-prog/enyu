//
//  ChannelChatView.swift
//  EarthLord
//
//  聊天界面页面
//  Day 34 实现
//

import SwiftUI
import Supabase
import UIKit
import CoreLocation

struct ChannelChatView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    let channel: CommunicationChannel

    @State private var messageText = ""
    @State private var scrollToBottom = false
    @FocusState private var isInputFocused: Bool

    private var currentUserId: UUID? {
        authManager.currentUser?.id
    }

    private var canSend: Bool {
        communicationManager.currentDevice?.deviceType.canSend ?? false
    }

    private var messages: [ChannelMessage] {
        communicationManager.getMessages(for: channel.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 导航栏
            headerView

            // 消息列表
            messageListView

            // 输入栏或只读提示
            if canSend {
                inputBarView
            } else {
                radioModeView
            }
        }
        .background(ApocalypseTheme.background)
        .task {
            await setupChat()
        }
        .onDisappear {
            communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
        }
    }

    // MARK: - 头部视图

    private var headerView: some View {
        HStack(spacing: 12) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: channel.channelType.iconName)
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 频道信息
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(channel.memberCount) 成员")
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 频道码
            Text(channel.channelCode)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(6)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        emptyMessagesView
                    } else {
                        ForEach(messages) { message in
                            ChannelMessageBubbleView(
                                message: message,
                                isCurrentUser: message.senderId == currentUserId
                            )
                            .id(message.messageId)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                // 自动滚动到最新消息
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.messageId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: scrollToBottom) { _, newValue in
                if newValue, let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.messageId, anchor: .bottom)
                    }
                    scrollToBottom = false
                }
            }
        }
    }

    private var emptyMessagesView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 80)

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("成为第一个发言的人吧")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 输入栏

    private var inputBarView: some View {
        HStack(spacing: 12) {
            // 消息输入框
            TextField("输入消息...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)
                .lineLimit(1...4)
                .focused($isInputFocused)

            // 发送按钮
            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(canSendMessage ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
                        .frame(width: 40, height: 40)

                    if communicationManager.isSendingMessage {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    }
                }
            }
            .disabled(!canSendMessage || communicationManager.isSendingMessage)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.background)
    }

    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - 收音机模式提示

    private var radioModeView: some View {
        HStack(spacing: 8) {
            Image(systemName: "radio")
                .foregroundColor(ApocalypseTheme.warning)

            Text("收音机模式：只能接收消息，无法发送")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .padding()
        .background(ApocalypseTheme.warning.opacity(0.1))
    }

    // MARK: - 方法

    private func setupChat() async {
        // Day 35-B: 确保定位服务已启动
        if LocationManager.shared.userLocation == nil {
            LocationManager.shared.startUpdatingLocation()
        }

        // 订阅频道消息
        communicationManager.subscribeToChannelMessages(channelId: channel.id)

        // 加载历史消息
        await communicationManager.loadChannelMessages(channelId: channel.id)

        // 启动 Realtime 订阅（如果尚未启动）
        await communicationManager.startMessageRealtimeSubscription()

        // 滚动到底部
        scrollToBottom = true
    }

    private func sendMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        // 获取当前位置
        var latitude: Double?
        var longitude: Double?
        if let location = LocationManager.shared.userLocation {
            latitude = location.latitude
            longitude = location.longitude
        }

        // 清空输入框（发送前清空，给用户即时反馈）
        let messageToSend = content
        messageText = ""

        // 发送消息
        let success = await communicationManager.sendChannelMessage(
            channelId: channel.id,
            content: messageToSend,
            latitude: latitude,
            longitude: longitude
        )

        if !success {
            // 发送失败，恢复输入框内容
            messageText = messageToSend
        }
    }
}

// MARK: - 频道消息气泡视图

struct ChannelMessageBubbleView: View {
    let message: ChannelMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // 发送者名称（仅他人消息显示）
                if !isCurrentUser {
                    HStack(spacing: 4) {
                        Text(message.senderCallsign ?? "匿名幸存者")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.primary)

                        // 设备类型图标
                        if let deviceType = message.deviceType {
                            deviceIcon(for: deviceType)
                        }
                    }
                }

                // 消息内容
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isCurrentUser ? .white : ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isCurrentUser
                            ? ApocalypseTheme.primary
                            : ApocalypseTheme.cardBackground
                    )
                    .cornerRadius(16, corners: isCurrentUser
                        ? [.topLeft, .topRight, .bottomLeft]
                        : [.topLeft, .topRight, .bottomRight]
                    )

                // 时间
                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }

    private func deviceIcon(for deviceType: String) -> some View {
        let iconName: String
        switch deviceType {
        case "radio":
            iconName = "radio"
        case "walkie_talkie":
            iconName = "phone.fill"
        case "camp_radio":
            iconName = "antenna.radiowaves.left.and.right"
        case "satellite":
            iconName = "antenna.radiowaves.left.and.right.circle"
        default:
            iconName = "wave.3.right"
        }

        return Image(systemName: iconName)
            .font(.caption2)
            .foregroundColor(ApocalypseTheme.textSecondary)
    }
}

// MARK: - 圆角扩展

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    let sampleChannel = CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .publicChannel,
        channelCode: "PUB-ABC123",
        name: "测试频道",
        description: "这是一个测试频道",
        isActive: true,
        memberCount: 42,
        createdAt: Date(),
        updatedAt: Date()
    )

    return ChannelChatView(channel: sampleChannel)
        .environmentObject(AuthManager.shared)
}
