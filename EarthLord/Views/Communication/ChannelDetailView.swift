//
//  ChannelDetailView.swift
//  EarthLord
//
//  频道详情页面
//  Day 33 实现
//

import SwiftUI
import Supabase

struct ChannelDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    let channel: CommunicationChannel

    @State private var isProcessing = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    private var isCreator: Bool {
        authManager.currentUser?.id == channel.creatorId
    }

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道头像和基本信息
                    headerSection

                    // 频道码
                    channelCodeSection

                    // 频道描述
                    if let description = channel.description, !description.isEmpty {
                        descriptionSection(description)
                    }

                    // 统计信息
                    statsSection

                    // 错误提示
                    if let error = errorMessage {
                        errorView(error)
                    }

                    // 操作按钮
                    actionButtons

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("频道详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("确认删除", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    Task {
                        await deleteChannel()
                    }
                }
            } message: {
                Text("删除频道后无法恢复，所有订阅者将自动退出。确定要删除吗？")
            }
        }
    }

    // MARK: - 头部区域

    private var headerSection: some View {
        VStack(spacing: 16) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 频道名称
            Text(channel.name)
                .font(.title2).fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 状态标签
            HStack(spacing: 8) {
                // 频道类型
                Label(channel.channelType.displayName, systemImage: channel.channelType.iconName)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(6)

                // 订阅状态
                if isSubscribed {
                    Label("已订阅", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ApocalypseTheme.success.opacity(0.15))
                        .cornerRadius(6)
                }

                // 创建者标识
                if isCreator {
                    Label("创建者", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ApocalypseTheme.warning.opacity(0.15))
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - 频道码

    private var channelCodeSection: some View {
        VStack(spacing: 8) {
            Text("频道码")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            HStack {
                Text(channel.channelCode)
                    .font(.title3).fontWeight(.medium)
                    .fontDesign(.monospaced)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Button {
                    UIPasteboard.general.string = channel.channelCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - 频道描述

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("频道简介")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(description)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
        }
    }

    // MARK: - 统计信息

    private var statsSection: some View {
        HStack(spacing: 16) {
            statItem(value: "\(channel.memberCount)", label: "成员", icon: "person.2.fill")

            Divider()
                .frame(height: 40)

            statItem(value: formattedDate(channel.createdAt), label: "创建于", icon: "calendar")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(ApocalypseTheme.primary)

            Text(value)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    // MARK: - 错误视图

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ApocalypseTheme.danger)

            Text(message)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.danger)

            Spacer()
        }
        .padding(12)
        .background(ApocalypseTheme.danger.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - 操作按钮

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 非创建者：订阅/取消订阅按钮
            if !isCreator {
                if isSubscribed {
                    Button {
                        Task {
                            await unsubscribe()
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.textSecondary))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "xmark.circle")
                            }
                            Text("取消订阅")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ApocalypseTheme.cardBackground)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ApocalypseTheme.textSecondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(isProcessing)
                } else {
                    Button {
                        Task {
                            await subscribe()
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text("订阅频道")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ApocalypseTheme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                }
            }

            // 创建者：删除按钮
            if isCreator {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("删除频道")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.danger.opacity(0.15))
                    .foregroundColor(ApocalypseTheme.danger)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - 操作方法

    private func subscribe() async {
        guard let userId = authManager.currentUser?.id else { return }

        isProcessing = true
        errorMessage = nil

        let result = await communicationManager.subscribeToChannel(userId: userId, channelId: channel.id)

        isProcessing = false

        if case .failure(let error) = result {
            errorMessage = error.localizedDescription
        }
    }

    private func unsubscribe() async {
        guard let userId = authManager.currentUser?.id else { return }

        isProcessing = true
        errorMessage = nil

        let result = await communicationManager.unsubscribeFromChannel(userId: userId, channelId: channel.id)

        isProcessing = false

        if case .failure(let error) = result {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteChannel() async {
        isProcessing = true
        errorMessage = nil

        let result = await communicationManager.deleteChannel(channelId: channel.id)

        isProcessing = false

        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    let sampleChannel = CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .publicChannel,
        channelCode: "PUB-ABC123",
        name: "测试频道",
        description: "这是一个测试频道的描述",
        isActive: true,
        memberCount: 42,
        createdAt: Date(),
        updatedAt: Date()
    )

    return ChannelDetailView(channel: sampleChannel)
        .environmentObject(AuthManager.shared)
}
