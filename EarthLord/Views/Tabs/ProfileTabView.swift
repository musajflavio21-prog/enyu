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
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var mailboxManager = MailboxManager.shared
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountSheet = false
    @State private var showStoreSheet = false
    @State private var showMailboxSheet = false
    @State private var deleteConfirmText = ""
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?

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

                        // 邮箱横幅（有待领取物资时显示）
                        MailboxBannerView(mailboxManager: mailboxManager) {
                            showMailboxSheet = true
                        }

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
            .sheet(isPresented: $showStoreSheet) {
                StoreView()
            }
            .sheet(isPresented: $showDeleteAccountSheet) {
                deleteAccountSheet
            }
            .sheet(isPresented: $showMailboxSheet) {
                MailboxView()
            }
            .task {
                await mailboxManager.loadPendingItems()
            }
        }
    }

    // MARK: - 删除账号确认弹窗

    private var deleteAccountSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 警告图标
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                        .padding(.top, 20)

                    // 标题
                    Text("删除账号")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 警告说明
                    VStack(alignment: .leading, spacing: 12) {
                        warningItem("此操作不可撤销")
                        warningItem("所有数据将被永久删除")
                        warningItem("无法恢复账号和游戏进度")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding(.horizontal)

                    // 输入确认
                    VStack(alignment: .leading, spacing: 8) {
                        Text("请输入「删除」以确认操作")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        TextField("输入「删除」", text: $deleteConfirmText)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal)

                    // 错误信息
                    if let errorMessage = deleteErrorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    Spacer()

                    // 按钮区域
                    VStack(spacing: 12) {
                        // 删除按钮
                        Button(action: {
                            performDeleteAccount()
                        }) {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "trash.fill")
                                }
                                Text(isDeleting ? "正在删除..." : "确认删除账号")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(deleteConfirmText == "删除" && !isDeleting ? Color.red : Color.gray)
                            )
                        }
                        .disabled(deleteConfirmText != "删除" || isDeleting)

                        // 取消按钮
                        Button(action: {
                            resetDeleteState()
                            showDeleteAccountSheet = false
                        }) {
                            Text("取消")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(ApocalypseTheme.textSecondary.opacity(0.5), lineWidth: 1)
                                )
                        }
                        .disabled(isDeleting)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        resetDeleteState()
                        showDeleteAccountSheet = false
                    }
                    .disabled(isDeleting)
                }
            }
            .interactiveDismissDisabled(isDeleting)
        }
        .presentationDetents([.medium, .large])
    }

    private func warningItem(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
            Text(text)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    private func performDeleteAccount() {
        print("🔵 [删除账户] 用户确认删除，开始执行...")
        isDeleting = true
        deleteErrorMessage = nil

        Task {
            do {
                // 1. 获取会话
                print("🔵 [删除账户] 正在获取会话...")
                let session = try await authManager.supabaseClient.auth.session
                print("✅ [删除账户] 会话有效，用户ID: \(session.user.id)")

                // 2. 调用边缘函数
                print("🔵 [删除账户] 正在调用边缘函数...")
                try await authManager.supabaseClient.functions.invoke(
                    "delete-account",
                    options: .init(
                        method: .post,
                        headers: [
                            "Authorization": "Bearer \(session.accessToken)"
                        ]
                    )
                )

                // 3. 删除成功
                print("✅ [删除账户] 账户删除成功！")
                await MainActor.run {
                    isDeleting = false
                    showDeleteAccountSheet = false
                    resetDeleteState()
                }

                // 4. 登出清理状态
                await authManager.signOut()

            } catch {
                print("❌ [删除账户] 删除失败: \(error)")
                await MainActor.run {
                    isDeleting = false

                    // 检查是否是网络错误但可能已经成功
                    let errorString = error.localizedDescription
                    if errorString.contains("connection was lost") ||
                       errorString.contains("network") ||
                       errorString.contains("NSURLErrorDomain") {
                        deleteErrorMessage = "网络连接中断，请检查账户状态后重试"
                    } else {
                        deleteErrorMessage = "删除失败: \(errorString)"
                    }
                }
            }
        }
    }

    private func resetDeleteState() {
        deleteConfirmText = ""
        deleteErrorMessage = nil
        isDeleting = false
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

            // 用户名/邮箱 + VIP徽章
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    VIPBadgeLargeView(tier: storeManager.currentVIPTier)
                }

                Text(authManager.currentUser?.email ?? "未知邮箱")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                // 末日币余额
                if storeManager.coinBalance > 0 {
                    CoinBalanceView()
                        .padding(.top, 4)
                }
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

            // 商店入口
            Button(action: { showStoreSheet = true }) {
                HStack(spacing: 16) {
                    Image(systemName: "bag.fill")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.warning)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("商店")
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("NEW")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(ApocalypseTheme.primary)
                                .cornerRadius(3)
                        }

                        Text("VIP会员、末日币、物资包、功能解锁")
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
            }
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            menuItem(icon: "questionmark.circle", title: "帮助与反馈", subtitle: "常见问题和意见反馈")
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 技术支持链接
            linkMenuItem(icon: "lifepreserver", title: "技术支持", subtitle: "访问支持页面获取帮助", url: "https://musajflavio21-prog.github.io/earthlord-support/")
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 隐私政策链接
            linkMenuItem(icon: "hand.raised", title: "隐私政策", subtitle: "查看我们的隐私保护政策", url: "https://musajflavio21-prog.github.io/earthlord-support/privacy.html")
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 删除账号菜单项
            deleteAccountMenuItem
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 删除账号菜单项

    private var deleteAccountMenuItem: some View {
        Button(action: {
            showDeleteAccountSheet = true
        }) {
            HStack(spacing: 16) {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("删除账号")
                        .font(.body)
                        .foregroundColor(.red)

                    Text("永久删除账号和所有数据")
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
        }
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

    // 链接菜单项（打开外部网页）
    private func linkMenuItem(icon: String, title: String, subtitle: String, url: String) -> some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
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

                Image(systemName: "arrow.up.forward.square")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding()
            .contentShape(Rectangle())
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
