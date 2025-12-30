//
//  AuthManager.swift
//  EarthLord
//
//  Created by enyu on 2025/12/24.
//

import Foundation
import Combine
import Supabase

/// 认证管理器
/// 负责处理用户注册、登录、找回密码等认证相关功能
///
/// 认证流程说明：
/// - 注册：发验证码 → 验证（已登录但无密码）→ 强制设置密码 → 完成
/// - 登录：邮箱 + 密码（直接登录）
/// - 找回密码：发验证码 → 验证（已登录）→ 设置新密码 → 完成
@MainActor
class AuthManager: ObservableObject {

    // MARK: - 单例

    static let shared = AuthManager()

    // MARK: - 发布属性

    /// 是否已认证（已登录且完成所有流程）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP验证后需要设置密码才能进入主页）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 验证码是否已发送
    @Published var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - 私有属性

    /// Supabase 客户端
    private let supabase: SupabaseClient

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    // MARK: - 初始化

    private init() {
        // 初始化 Supabase 客户端
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://ikpvcdxtsghqbiszlaco.supabase.co")!,
            supabaseKey: "sb_publishable_iIRCvY4Dij9Qws5jL_NGMw_-yN5alvx"
        )

        // 启动认证状态监听
        startAuthStateListener()
    }

    // MARK: - 认证状态监听

    /// 启动认证状态变化监听
    /// - Note: 监听登录/登出事件，自动更新 UI 状态
    private func startAuthStateListener() {
        authStateTask = Task { [weak self] in
            guard let self = self else { return }

            // 监听认证状态变化
            for await (event, session) in self.supabase.auth.authStateChanges {
                await MainActor.run {
                    self.handleAuthStateChange(event: event, session: session)
                }
            }
        }
    }

    /// 处理认证状态变化
    /// - Parameters:
    ///   - event: 认证事件类型
    ///   - session: 当前会话（可能为空）
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) {
        print("🔄 认证状态变化: \(event)")

        switch event {
        case .signedIn:
            // 用户已登录
            if let session = session {
                currentUser = session.user
                // 注意：如果是 OTP 注册流程，需要检查是否需要设置密码
                // 这里仅处理正常登录情况
                if !needsPasswordSetup {
                    isAuthenticated = true
                }
                print("✅ 用户已登录: \(session.user.email ?? "未知邮箱")")
            }

        case .signedOut:
            // 用户已登出
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false
            print("✅ 用户已登出")

        case .tokenRefreshed:
            // Token 已刷新
            if let session = session {
                currentUser = session.user
                isAuthenticated = true
                print("🔄 Token 已刷新")
            } else {
                // Token 刷新失败，会话过期
                handleSessionExpired()
            }

        case .userUpdated:
            // 用户信息已更新
            if let session = session {
                currentUser = session.user
                print("🔄 用户信息已更新")
            }

        case .passwordRecovery:
            // 密码恢复流程
            print("🔄 进入密码恢复流程")

        default:
            print("🔄 其他认证事件: \(event)")
        }
    }

    /// 停止认证状态监听
    /// - Note: 在不需要时调用以释放资源
    func stopAuthStateListener() {
        authStateTask?.cancel()
        authStateTask = nil
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    /// - Note: 调用 signInWithOTP，shouldCreateUser 为 true 表示如果用户不存在则创建
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送 OTP 验证码，如果用户不存在则创建
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            otpSent = true
            print("✅ 注册验证码已发送至: \(email)")

        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    /// - Note: 验证成功后用户已登录，但 isAuthenticated 保持 false，需要设置密码
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP，type 为 .email
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录
            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true
            // 注意：isAuthenticated 保持 false，必须设置密码后才能进入主页

            print("✅ 注册验证码验证成功，用户已登录，等待设置密码")

        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 验证注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户设置的密码
    /// - Note: 必须在 verifyRegisterOTP 成功后调用
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: password))

            // 设置密码成功，完成注册流程
            needsPasswordSetup = false
            isAuthenticated = true

            print("✅ 密码设置成功，注册流程完成")

        } catch {
            errorMessage = "设置密码失败: \(error.localizedDescription)"
            print("❌ 设置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录方法

    /// 使用邮箱和密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 邮箱密码登录
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            // 登录成功
            currentUser = session.user
            isAuthenticated = true

            print("✅ 登录成功: \(email)")

        } catch {
            errorMessage = "登录失败: \(error.localizedDescription)"
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送重置密码验证码
    /// - Parameter email: 用户邮箱
    /// - Note: 这会触发 Supabase 的 Reset Password 邮件模板
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送重置密码邮件
            try await supabase.auth.resetPasswordForEmail(email)

            otpSent = true
            print("✅ 重置密码验证码已发送至: \(email)")

        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送重置密码验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证重置密码验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    /// - Note: ⚠️ type 是 .recovery 不是 .email
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP，⚠️ type 为 .recovery（重置密码专用）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功，用户已登录
            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true

            print("✅ 重置密码验证码验证成功，等待设置新密码")

        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 验证重置密码验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    /// - Note: 必须在 verifyResetOTP 成功后调用
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: newPassword))

            // 设置密码成功
            needsPasswordSetup = false
            isAuthenticated = true

            print("✅ 密码重置成功")

        } catch {
            errorMessage = "重置密码失败: \(error.localizedDescription)"
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// 使用 Apple 登录
    /// - Note: TODO: 实现 Apple Sign In
    func signInWithApple() async {
        // TODO: 实现 Apple Sign In
        // 1. 使用 AuthenticationServices 获取 Apple 凭证
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        // 3. 设置 isAuthenticated = true
        print("⚠️ Apple 登录功能待实现")
    }

    /// 使用 Google 登录
    /// - Note: TODO: 实现 Google Sign In
    func signInWithGoogle() async {
        // TODO: 实现 Google Sign In
        // 1. 使用 GoogleSignIn SDK 获取 Google 凭证
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        // 3. 设置 isAuthenticated = true
        print("⚠️ Google 登录功能待实现")
    }

    // MARK: - 其他方法

    /// 登出
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            // 重置所有状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false

            print("✅ 已登出")

        } catch {
            errorMessage = "登出失败: \(error.localizedDescription)"
            print("❌ 登出失败: \(error)")
        }

        isLoading = false
    }

    /// 检查当前会话状态
    /// - Note: 应在 App 启动时调用，恢复登录状态
    func checkSession() async {
        isLoading = true

        do {
            // 获取当前会话
            let session = try await supabase.auth.session
            currentUser = session.user

            // 检查用户是否有密码（通过检查 identities）
            // 如果用户通过 OTP 注册但未设置密码，需要继续设置密码流程
            if let identities = session.user.identities,
               identities.contains(where: { $0.provider == "email" }) {
                // 用户有邮箱身份，检查是否完成了注册
                // 这里简单处理：如果能获取到会话，认为已完成注册
                isAuthenticated = true
                needsPasswordSetup = false
            } else {
                // 没有邮箱身份，可能是第三方登录
                isAuthenticated = true
                needsPasswordSetup = false
            }

            print("✅ 会话有效，用户已登录: \(session.user.email ?? "未知邮箱")")

        } catch {
            // 没有有效会话，用户未登录
            isAuthenticated = false
            currentUser = nil
            print("ℹ️ 无有效会话，用户未登录")
        }

        isLoading = false
    }

    // MARK: - 会话过期处理

    /// 处理会话过期
    /// - Note: 当 Token 刷新失败或会话无效时调用
    private func handleSessionExpired() {
        print("⚠️ 会话已过期，需要重新登录")

        // 清空所有状态
        isAuthenticated = false
        needsPasswordSetup = false
        currentUser = nil
        otpSent = false
        otpVerified = false
        errorMessage = "会话已过期，请重新登录"
    }

    // MARK: - 辅助方法

    /// 重置流程状态
    /// - Note: 在用户取消操作或切换流程时调用
    func resetFlowState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        errorMessage = nil
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }
}
