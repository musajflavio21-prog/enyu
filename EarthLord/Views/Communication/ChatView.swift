//
//  ChatView.swift
//  EarthLord
//
//  通讯聊天主视图
//  包含频道切换、消息列表、消息输入等功能
//

import SwiftUI

/// 聊天视图
struct ChatView: View {

    // MARK: - 状态

    /// 通讯管理器
    @StateObject private var communicationManager = CommunicationManager.shared

    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 消息输入内容
    @State private var messageInput = ""

    /// 是否显示频道选择器
    @State private var showChannelPicker = false

    /// 是否正在发送消息
    @State private var isSending = false

    /// 是否显示错误提示
    @State private var showError = false

    /// 滚动代理
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部栏
                headerView

                // 消息列表
                messageListView

                // 输入栏
                inputBarView
            }

            // 频道选择器
            if showChannelPicker {
                channelPickerOverlay
            }

            // 加载指示器
            if communicationManager.isLoading && communicationManager.messages.isEmpty {
                loadingOverlay
            }
        }
        .onAppear {
            Task {
                await communicationManager.connect()
            }
        }
        .onDisappear {
            Task {
                await communicationManager.disconnect()
            }
        }
        .onChange(of: communicationManager.errorMessage) { _, error in
            if error != nil {
                showError = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showError = false
                    communicationManager.clearError()
                }
            }
        }
    }

    // MARK: - 顶部栏

    private var headerView: some View {
        HStack {
            // 频道选择按钮
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showChannelPicker.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: communicationManager.currentChannel.iconName)
                        .font(.system(size: 16))

                    Text(communicationManager.currentChannel.displayName)
                        .font(.headline)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .rotationEffect(.degrees(showChannelPicker ? 180 : 0))
                }
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
            }

            Spacer()

            // 连接状态
            HStack(spacing: 6) {
                Circle()
                    .fill(communicationManager.isConnected ? ApocalypseTheme.success : ApocalypseTheme.danger)
                    .frame(width: 8, height: 8)

                Text(communicationManager.isConnected ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 附近玩家数量（仅附近频道显示）
            if communicationManager.currentChannel == .nearby {
                Button {
                    Task {
                        await communicationManager.discoverNearbyPlayers()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                        Text("\(communicationManager.nearbyPlayers.count)")
                            .font(.caption)
                    }
                    .foregroundColor(ApocalypseTheme.info)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.info.opacity(0.2))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // 加载更多按钮
                    if !communicationManager.messages.isEmpty {
                        Button {
                            Task {
                                if let firstMessage = communicationManager.messages.first {
                                    await communicationManager.loadMoreMessages(beforeDate: firstMessage.createdAt)
                                }
                            }
                        } label: {
                            Text("加载更多消息")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .padding(.vertical, 8)
                        }
                    }

                    // 消息列表
                    ForEach(communicationManager.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: message.isFromCurrentUser(currentUserId: authManager.currentUser?.id)
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: communicationManager.messages.count) { _, _ in
                // 新消息时滚动到底部
                if let lastMessage = communicationManager.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - 输入栏

    private var inputBarView: some View {
        VStack(spacing: 0) {
            // 频道限制提示
            if let restriction = communicationManager.channelAvailabilityDescription(for: communicationManager.currentChannel) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text(restriction)
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.warning)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(ApocalypseTheme.warning.opacity(0.1))
            }

            // 输入框
            HStack(spacing: 12) {
                // 附加功能按钮
                Button {
                    // 分享位置
                    Task {
                        if let userLocation = LocationManager.shared.userLocation {
                            _ = await communicationManager.sendLocationMessage(
                                latitude: userLocation.latitude,
                                longitude: userLocation.longitude,
                                channel: communicationManager.currentChannel
                            )
                        }
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 文本输入框
                TextField("输入消息...", text: $messageInput)
                    .textFieldStyle(.plain)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(20)
                    .onSubmit {
                        sendMessage()
                    }

                // 发送按钮
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(canSend ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.cardBackground.opacity(0.95))
        }
    }

    // MARK: - 频道选择器

    private var channelPickerOverlay: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showChannelPicker = false
                    }
                }

            // 频道列表
            VStack(spacing: 0) {
                ForEach(ChatChannel.allCases, id: \.rawValue) { channel in
                    Button {
                        Task {
                            await communicationManager.switchChannel(channel)
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showChannelPicker = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: channel.iconName)
                                .font(.system(size: 20))
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(channel.displayName)
                                    .font(.headline)

                                Text(channel.description)
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }

                            Spacer()

                            if channel == communicationManager.currentChannel {
                                Image(systemName: "checkmark")
                                    .foregroundColor(ApocalypseTheme.primary)
                            }
                        }
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    if channel != ChatChannel.allCases.last {
                        Divider()
                            .background(ApocalypseTheme.textMuted)
                    }
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 40)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
        .transition(.opacity)
    }

    // MARK: - 加载指示器

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text("正在连接...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background.opacity(0.8))
    }

    // MARK: - 辅助方法

    /// 是否可以发送消息
    private var canSend: Bool {
        !messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSending &&
        communicationManager.canSendTo(channel: communicationManager.currentChannel)
    }

    /// 发送消息
    private func sendMessage() {
        let content = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSending = true
        messageInput = ""

        Task {
            let result = await communicationManager.sendMessage(
                content: content,
                channel: communicationManager.currentChannel
            )

            isSending = false

            if case .failure(let error) = result {
                print("❌ 发送消息失败: \(error)")
            }
        }
    }
}

// MARK: - 消息气泡视图

/// 单条消息气泡
struct MessageBubbleView: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }

            // 头像（非自己的消息显示）
            if !isFromCurrentUser {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(message.senderUsername?.prefix(1).uppercased() ?? "?"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.primary)
                    )
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // 发送者名称（非自己的消息显示）
                if !isFromCurrentUser {
                    Text(message.senderUsername ?? "匿名")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 消息内容
                messageContentView

                // 时间
                Text(message.formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }

    @ViewBuilder
    private var messageContentView: some View {
        switch message.messageType {
        case .text:
            Text(message.content)
                .font(.body)
                .foregroundColor(isFromCurrentUser ? .white : ApocalypseTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isFromCurrentUser ?
                    ApocalypseTheme.primary :
                    ApocalypseTheme.cardBackground
                )
                .cornerRadius(16)

        case .location:
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .foregroundColor(ApocalypseTheme.info)
                Text("分享了位置")
                    .font(.body)
            }
            .foregroundColor(ApocalypseTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)

        case .system:
            Text(message.content)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .cornerRadius(12)

        default:
            Text(message.content)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(16)
        }
    }
}

#Preview {
    ChatView()
}
