//
//  ChannelCenterView.swift
//  EarthLord
//
//  频道中心页面
//  Day 33 实现
//

import SwiftUI
import Supabase

struct ChannelCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?
    @State private var chatChannel: CommunicationChannel?

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            // Tab 选择器
            tabSelector

            // 内容区域
            TabView(selection: $selectedTab) {
                myChannelsView
                    .tag(0)

                discoverChannelsView
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(ApocalypseTheme.background)
        .task {
            await loadData()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateChannelSheet()
                .environmentObject(authManager)
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelDetailView(channel: channel)
                .environmentObject(authManager)
        }
        .fullScreenCover(item: $chatChannel) { channel in
            NavigationStack {
                ChannelChatView(channel: channel)
                    .environmentObject(authManager)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                chatChannel = nil
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("返回")
                                }
                                .foregroundColor(ApocalypseTheme.primary)
                            }
                        }

                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                // 打开频道详情
                                chatChannel = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    selectedChannel = channel
                                }
                            } label: {
                                Image(systemName: "info.circle")
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
            Text("频道中心")
                .font(.title2).fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Button {
                showCreateSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Tab 选择器

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "我的频道", index: 0)
            tabButton(title: "发现频道", index: 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                Rectangle()
                    .fill(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 我的频道

    private var myChannelsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if communicationManager.subscribedChannels.isEmpty {
                    emptyStateView(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "暂无订阅频道",
                        subtitle: "去「发现频道」找找感兴趣的频道吧"
                    )
                } else {
                    ForEach(communicationManager.subscribedChannels) { subscribedChannel in
                        channelRow(channel: subscribedChannel.channel, isSubscribed: true)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - 发现频道

    private var discoverChannelsView: some View {
        VStack(spacing: 0) {
            // 搜索框
            searchBar

            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredChannels.isEmpty {
                        emptyStateView(
                            icon: "magnifyingglass",
                            title: "没有找到频道",
                            subtitle: searchText.isEmpty ? "暂无公开频道，点击 + 创建一个" : "试试其他关键词"
                        )
                    } else {
                        ForEach(filteredChannels) { channel in
                            channelRow(channel: channel, isSubscribed: communicationManager.isSubscribed(channelId: channel.id))
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField("搜索频道...", text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var filteredChannels: [CommunicationChannel] {
        if searchText.isEmpty {
            return communicationManager.channels
        }
        return communicationManager.channels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.channelCode.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    // MARK: - 频道行

    private func channelRow(channel: CommunicationChannel, isSubscribed: Bool) -> some View {
        Button {
            if isSubscribed {
                // 已订阅：进入聊天界面
                chatChannel = channel
            } else {
                // 未订阅：进入频道详情（订阅页面）
                selectedChannel = channel
            }
        } label: {
            HStack(spacing: 12) {
                // 频道图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: channel.channelType.iconName)
                        .font(.title3)
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 频道信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(channel.name)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        if isSubscribed {
                            Text("已订阅")
                                .font(.caption2)
                                .foregroundColor(ApocalypseTheme.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ApocalypseTheme.success.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }

                    Text(channel.channelCode)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .fontDesign(.monospaced)

                    HStack(spacing: 12) {
                        Label("\(channel.memberCount)", systemImage: "person.2")
                        Label(channel.channelType.displayName, systemImage: channel.channelType.iconName)
                    }
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

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

    // MARK: - 空状态视图

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 数据加载

    private func loadData() async {
        await communicationManager.loadPublicChannels()
        if let userId = authManager.currentUser?.id {
            await communicationManager.loadSubscribedChannels(userId: userId)
        }
    }
}

#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager.shared)
}
