//
//  CreateChannelSheet.swift
//  EarthLord
//
//  创建频道弹窗
//  Day 33 实现
//

import SwiftUI
import Supabase

struct CreateChannelSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var selectedType: ChannelType = .publicChannel
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let nameMinLength = 2
    private let nameMaxLength = 50
    private let descriptionMaxLength = 200

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道类型选择
                    typeSelectionSection

                    // 频道名称
                    nameInputSection

                    // 频道描述
                    descriptionInputSection

                    // 错误提示
                    if let error = errorMessage {
                        errorView(error)
                    }

                    // 创建按钮
                    createButton
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 类型选择

    private var typeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("频道类型")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 8) {
                ForEach(ChannelType.creatableTypes, id: \.self) { type in
                    typeOptionRow(type)
                }
            }
        }
    }

    private func typeOptionRow(_ type: ChannelType) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = type
            }
        } label: {
            HStack(spacing: 12) {
                // 选中状态
                ZStack {
                    Circle()
                        .stroke(selectedType == type ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if selectedType == type {
                        Circle()
                            .fill(ApocalypseTheme.primary)
                            .frame(width: 12, height: 12)
                    }
                }

                // 图标
                Image(systemName: type.iconName)
                    .font(.title3)
                    .foregroundColor(selectedType == type ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                    .frame(width: 30)

                // 文字
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedType == type ? ApocalypseTheme.primary.opacity(0.1) : ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedType == type ? ApocalypseTheme.primary.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 名称输入

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("频道名称")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(channelName.count)/\(nameMaxLength)")
                    .font(.caption)
                    .foregroundColor(isNameValid ? ApocalypseTheme.textSecondary : ApocalypseTheme.danger)
            }

            TextField("输入频道名称", text: $channelName)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .onChange(of: channelName) { _, newValue in
                    if newValue.count > nameMaxLength {
                        channelName = String(newValue.prefix(nameMaxLength))
                    }
                }

            if channelName.count > 0 && channelName.count < nameMinLength {
                Text("名称至少需要 \(nameMinLength) 个字符")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }
        }
    }

    private var isNameValid: Bool {
        channelName.count >= nameMinLength && channelName.count <= nameMaxLength
    }

    // MARK: - 描述输入

    private var descriptionInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("频道描述")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("(可选)")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(channelDescription.count)/\(descriptionMaxLength)")
                    .font(.caption)
                    .foregroundColor(channelDescription.count > descriptionMaxLength ? ApocalypseTheme.danger : ApocalypseTheme.textSecondary)
            }

            TextEditor(text: $channelDescription)
                .frame(minHeight: 80, maxHeight: 120)
                .padding(8)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .onChange(of: channelDescription) { _, newValue in
                    if newValue.count > descriptionMaxLength {
                        channelDescription = String(newValue.prefix(descriptionMaxLength))
                    }
                }
        }
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

    // MARK: - 创建按钮

    private var createButton: some View {
        Button {
            Task {
                await createChannel()
            }
        } label: {
            HStack {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                }

                Text(isCreating ? "创建中..." : "创建频道")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canCreate ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canCreate || isCreating)
    }

    private var canCreate: Bool {
        isNameValid && !isCreating
    }

    // MARK: - 创建逻辑

    private func createChannel() async {
        guard let userId = authManager.currentUserId else {
            errorMessage = "请先登录"
            return
        }

        isCreating = true
        errorMessage = nil

        let result = await communicationManager.createChannel(
            userId: userId,
            type: selectedType,
            name: channelName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: channelDescription.isEmpty ? nil : channelDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        isCreating = false

        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CreateChannelSheet()
        .environmentObject(AuthManager.shared)
}
