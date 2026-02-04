//
//  OfficialChannelDetailView.swift
//  EarthLord
//
//  官方频道详情页面
//  Day 36 实现
//

import SwiftUI

struct OfficialChannelDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedCategory: MessageCategory? = nil
    @State private var isLoading = false

    private var messages: [ChannelMessage] {
        let allMessages = communicationManager.getMessages(for: CommunicationManager.officialChannelId)

        if let category = selectedCategory {
            return allMessages.filter { $0.metadata?.category == category.rawValue }
        }
        return allMessages
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部导航栏
            headerView

            // 分类过滤器
            categoryFilterView

            // 消息列表
            messageListView
        }
        .background(ApocalypseTheme.background)
        .task {
            await loadMessages()
        }
    }

    // MARK: - 头部视图

    private var headerView: some View {
        HStack(spacing: 12) {
            // 返回按钮
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
                .foregroundColor(ApocalypseTheme.primary)
            }

            Spacer()

            // 频道名称
            HStack(spacing: 8) {
                Image(systemName: "megaphone.fill")
                    .foregroundColor(ApocalypseTheme.warning)
                Text("末日广播站")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()

            // 占位符保持居中
            Color.clear
                .frame(width: 60)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 分类过滤器

    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部
                CategoryChip(
                    title: "全部",
                    iconName: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    color: ApocalypseTheme.primary
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }

                // 各分类
                ForEach(MessageCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        iconName: category.iconName,
                        isSelected: selectedCategory == category,
                        color: categoryColor(for: category)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    private func categoryColor(for category: MessageCategory) -> Color {
        switch category {
        case .survival: return .green
        case .news: return .blue
        case .mission: return .orange
        case .alert: return .red
        }
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if isLoading {
                    loadingView
                } else if messages.isEmpty {
                    emptyStateView
                } else {
                    ForEach(messages) { message in
                        OfficialMessageBubble(message: message)
                    }
                }
            }
            .padding()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 80)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.2)

            Text("正在接收广播...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 80)

            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无广播")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(selectedCategory == nil ? "官方暂无发布任何消息" : "该分类暂无消息")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 方法

    private func loadMessages() async {
        isLoading = true
        await communicationManager.loadChannelMessages(channelId: CommunicationManager.officialChannelId, limit: 50)
        isLoading = false
    }
}

// MARK: - 分类芯片组件

struct CategoryChip: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? color : color.opacity(0.15)
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 官方消息气泡

struct OfficialMessageBubble: View {
    let message: ChannelMessage

    private var category: MessageCategory? {
        guard let categoryString = message.metadata?.category else { return nil }
        return MessageCategory(rawValue: categoryString)
    }

    private var categoryColor: Color {
        guard let category = category else { return ApocalypseTheme.primary }
        switch category {
        case .survival: return .green
        case .news: return .blue
        case .mission: return .orange
        case .alert: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 头部：分类标签 + 时间
            HStack {
                if let category = category {
                    HStack(spacing: 4) {
                        Image(systemName: category.iconName)
                            .font(.caption2)
                        Text(category.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.15))
                    .cornerRadius(6)
                }

                Spacer()

                Text(message.timeAgo)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 消息内容
            Text(message.content)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .multilineTextAlignment(.leading)

            // 底部装饰线
            if category == .alert {
                Rectangle()
                    .fill(categoryColor.opacity(0.5))
                    .frame(height: 2)
            }
        }
        .padding()
        .background(
            category == .alert
                ? categoryColor.opacity(0.1)
                : ApocalypseTheme.cardBackground
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    category == .alert ? categoryColor.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    OfficialChannelDetailView()
        .environmentObject(AuthManager.shared)
}
