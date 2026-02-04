//
//  MessageCenterView.swift
//  EarthLord
//
//  消息中心页面
//  Day 36 实现
//

import SwiftUI

struct MessageCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var isLoading = false
    @State private var showOfficialChannel = false
    @State private var selectedChannel: CommunicationChannel?

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            // 内容
            ScrollView {
                LazyVStack(spacing: 12) {
                    // 官方频道（置顶）
                    officialChannelRow

                    // 分隔线
                    if !communicationManager.channelSummaries.isEmpty {
                        dividerView
                    }

                    // 其他订阅频道
                    if communicationManager.channelSummaries.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(communicationManager.channelSummaries.filter {
                            $0.channel.id != CommunicationManager.officialChannelId
                        }) { summary in
                            MessageRowView(summary: summary) {
                                selectedChannel = summary.channel
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(ApocalypseTheme.background)
        .task {
            await loadData()
        }
        .fullScreenCover(isPresented: $showOfficialChannel) {
            OfficialChannelDetailView()
                .environmentObject(authManager)
        }
        .sheet(item: $selectedChannel) { channel in
            NavigationStack {
                ChannelChatView(channel: channel)
                    .environmentObject(authManager)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                selectedChannel = nil
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("返回")
                                }
                                .foregroundColor(ApocalypseTheme.primary)
                            }
                        }
                    }
            }
        }
    }

    // MARK: - 头部视图

    private var headerView: some View {
        HStack {
            Text("消息中心")
                .font(.title2).fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 刷新按钮
            Button {
                Task {
                    await loadData()
                }
            } label: {
                Image(systemName: isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.primary)
                    .rotationEffect(isLoading ? .degrees(360) : .degrees(0))
                    .animation(isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
            }
            .disabled(isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - 官方频道行（置顶）

    private var officialChannelRow: some View {
        Button {
            showOfficialChannel = true
        } label: {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.warning.opacity(0.2))
                        .frame(width: 52, height: 52)

                    Image(systemName: "megaphone.fill")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.warning)
                }

                // 频道信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("末日广播站")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("官方")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ApocalypseTheme.warning)
                            .cornerRadius(4)
                    }

                    // 最新消息预览
                    if let latestMessage = communicationManager.getMessages(for: CommunicationManager.officialChannelId).last {
                        Text(latestMessage.content)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("官方公告、生存指南、任务发布")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                // 时间
                if let latestMessage = communicationManager.getMessages(for: CommunicationManager.officialChannelId).last {
                    Text(latestMessage.timeAgo)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.warning.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 分隔线

    private var dividerView: some View {
        HStack {
            Rectangle()
                .fill(ApocalypseTheme.textSecondary.opacity(0.2))
                .frame(height: 1)

            Text("已订阅频道")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Rectangle()
                .fill(ApocalypseTheme.textSecondary.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无订阅频道")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("去「频道中心」订阅感兴趣的频道")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 方法

    private func loadData() async {
        isLoading = true

        // 加载公开频道和订阅
        await communicationManager.loadPublicChannels()
        if let userId = authManager.currentUserId {
            await communicationManager.loadSubscribedChannels(userId: userId)
        }

        // 加载所有频道最新消息
        await communicationManager.loadAllChannelLatestMessages()

        isLoading = false
    }
}

// MARK: - 消息行视图

struct MessageRowView: View {
    let summary: ChannelSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 频道图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: summary.channel.channelType.iconName)
                        .font(.title3)
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 频道信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 最新消息预览
                    if let message = summary.latestMessage {
                        HStack(spacing: 4) {
                            if let callsign = message.senderCallsign {
                                Text("\(callsign):")
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.primary)
                            }
                            Text(message.content)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("暂无消息")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                // 时间和未读数
                VStack(alignment: .trailing, spacing: 4) {
                    if let message = summary.latestMessage {
                        Text(message.timeAgo)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    if summary.unreadCount > 0 {
                        Text("\(summary.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(10)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MessageCenterView()
        .environmentObject(AuthManager.shared)
}
