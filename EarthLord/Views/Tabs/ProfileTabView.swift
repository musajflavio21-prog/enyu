//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by enyu on 2025/12/24.
//

import SwiftUI
import Supabase

struct ProfileTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 用户头像和信息卡片
                        userInfoCard

                        // 功能列表
                        menuSection

                        // 退出登录按钮
                        logoutButton
                    }
                    .padding()
                }
            }
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.inline)
            .alert("确认退出", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("退出", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
            } message: {
                Text("确定要退出登录吗？")
            }
        }
    }

    // MARK: - 用户信息卡片

    private var userInfoCard: some View {
        VStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 10)

                // 用户首字母或默认图标
                if let email = authManager.currentUser?.email, let firstChar = email.first {
                    Text(String(firstChar).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }

            // 用户名/邮箱
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(authManager.currentUser?.email ?? "未知邮箱")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 用户ID（开发调试用）
            if let userId = authManager.currentUser?.id {
                Text("ID: \(userId.uuidString.prefix(8))...")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 菜单区域

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuItem(icon: "person.text.rectangle", title: "编辑资料", subtitle: "修改头像和昵称")
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            menuItem(icon: "shield.lefthalf.filled", title: "账号安全", subtitle: "密码和安全设置")
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            menuItem(icon: "bell.badge", title: "通知设置", subtitle: "推送和提醒")
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            menuItem(icon: "questionmark.circle", title: "帮助与反馈", subtitle: "常见问题和意见反馈")
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    private func menuItem(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: 导航到对应页面
        }
    }

    // MARK: - 退出登录按钮

    private var logoutButton: some View {
        Button(action: {
            showLogoutAlert = true
        }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("退出登录")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.8))
            )
        }
        .padding(.top, 8)
    }

    // MARK: - 辅助计算属性

    private var displayName: String {
        if let email = authManager.currentUser?.email {
            // 取邮箱@前面的部分作为显示名
            return String(email.split(separator: "@").first ?? "幸存者")
        }
        return "幸存者"
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager.shared)
}
