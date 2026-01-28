//
//  AuthManager.swift
//  EarthLord
//
//  Created by enyu on 2025/12/24.
//

import Foundation
import Combine
import Supabase
import GoogleSignIn
import AuthenticationServices
import CryptoKit

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

    /// 公开 Supabase 客户端（供视图直接调用边缘函数）
    var supabaseClient: SupabaseClient {
        return supabase
    }

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    /// Google Client ID
    private let googleClientID = "1032664613546-f4f8ni3cobpjlqf6fmrhvce335f8utfl.apps.googleusercontent.com"

    /// Apple Sign In 的 nonce（用于安全验证）
    private var currentNonce: String?

    // MARK: - 初始化

    private init() {
        // 初始化 Supabase 客户端
        // 使用 legacy anon key（与 Edge Functions 兼容性更好）
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://ikpvcdxtsghqbiszlaco.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlrcHZjZHh0c2docWJpc3psYWNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY3NTU5MDUsImV4cCI6MjA4MjMzMTkwNX0.M5tY-zyNpUjHE3p6b_QBmLgSaqCIekvC7uxHJvsIFt8",
            options: .init(
                auth: .init(
                    // 修复警告：使用新的会话发射行为
                    emitLocalSessionAsInitialSession: true
                )
            )
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

    // MARK: - 第三方登录

    /// 使用 Apple 登录
    /// - Note: 使用 AuthenticationServices 获取 Apple 凭证，然后通过 Supabase 验证
    func signInWithApple() async {
        print("🍎 [Apple登录] 开始 Apple 登录流程...")
        isLoading = true
        errorMessage = nil

        // 生成随机 nonce 用于安全验证
        let nonce = randomNonceString()
        currentNonce = nonce

        // 创建 Apple ID 请求
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        // 创建授权控制器
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])

        // 使用 continuation 来等待授权结果
        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
                let delegate = AppleSignInDelegate(continuation: continuation)
                authorizationController.delegate = delegate
                authorizationController.presentationContextProvider = delegate

                // 保持 delegate 引用
                objc_setAssociatedObject(authorizationController, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

                authorizationController.performRequests()
            }

            // 处理授权结果
            await handleAppleSignInResult(result)

        } catch let error as ASAuthorizationError {
            print("❌ [Apple登录] ASAuthorizationError: \(error.localizedDescription)")
            switch error.code {
            case .canceled:
                print("ℹ️ [Apple登录] 用户取消了登录")
                errorMessage = nil
            case .invalidResponse:
                errorMessage = "Apple 登录失败：响应无效"
            case .notHandled:
                errorMessage = "Apple 登录失败：请求未处理"
            case .failed:
                errorMessage = "Apple 登录失败：\(error.localizedDescription)"
            case .notInteractive:
                errorMessage = "Apple 登录失败：需要用户交互"
            case .unknown:
                errorMessage = "Apple 登录失败：未知错误"
            @unknown default:
                errorMessage = "Apple 登录失败：\(error.localizedDescription)"
            }
        } catch {
            print("❌ [Apple登录] 错误: \(error)")
            errorMessage = "Apple 登录失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 处理 Apple 登录结果
    private func handleAppleSignInResult(_ authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ [Apple登录] 无法获取 Apple ID 凭证")
            errorMessage = "Apple 登录失败：无法获取凭证"
            return
        }

        // 获取 identity token
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            print("❌ [Apple登录] 无法获取 identity token")
            errorMessage = "Apple 登录失败：无法获取令牌"
            return
        }

        print("✅ [Apple登录] 成功获取 identity token (长度: \(identityToken.count))")

        // 获取用户信息（仅首次登录时可用）
        let fullName = appleIDCredential.fullName
        let email = appleIDCredential.email

        if let email = email {
            print("🍎 [Apple登录] 用户邮箱: \(email)")
        }
        if let fullName = fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !name.isEmpty {
                print("🍎 [Apple登录] 用户姓名: \(name)")
            }
        }

        // 使用 Supabase 验证 Apple 凭证
        do {
            print("🍎 [Apple登录] 正在向 Supabase 发送验证请求...")
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: identityToken,
                    nonce: currentNonce
                )
            )

            // 登录成功
            currentUser = session.user
            isAuthenticated = true

            print("✅ [Apple登录] Supabase 验证成功！")
            print("✅ [Apple登录] 用户 ID: \(session.user.id)")
            print("✅ [Apple登录] 用户邮箱: \(session.user.email ?? "未知")")
            print("🎉 [Apple登录] Apple 登录流程完成！")

        } catch {
            print("❌ [Apple登录] Supabase 验证失败: \(error)")
            errorMessage = "Apple 登录失败: \(error.localizedDescription)"
        }
    }

    /// 生成随机 nonce 字符串
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    /// 对字符串进行 SHA256 哈希
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    /// 使用 Google 登录
    /// - Note: 使用 GoogleSignIn SDK 获取凭证，然后通过 Supabase 验证
    func signInWithGoogle() async {
        print("🔵 [Google登录] 开始 Google 登录流程...")
        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取当前窗口的 rootViewController
            print("🔵 [Google登录] 正在获取 rootViewController...")
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                print("❌ [Google登录] 无法获取 rootViewController")
                errorMessage = "无法启动 Google 登录"
                isLoading = false
                return
            }
            print("✅ [Google登录] 成功获取 rootViewController")

            // 2. 配置 Google Sign-In
            print("🔵 [Google登录] 正在配置 Google Sign-In...")
            let config = GIDConfiguration(clientID: googleClientID)
            GIDSignIn.sharedInstance.configuration = config
            print("✅ [Google登录] Google Sign-In 配置完成")

            // 3. 执行 Google 登录（在主线程上）
            print("🔵 [Google登录] 正在弹出 Google 登录界面...")
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            print("✅ [Google登录] Google 登录界面返回成功")

            // 4. 获取用户信息
            let user = result.user
            print("🔵 [Google登录] 用户邮箱: \(user.profile?.email ?? "未知")")
            print("🔵 [Google登录] 用户名称: \(user.profile?.name ?? "未知")")

            // 5. 获取 ID Token
            print("🔵 [Google登录] 正在获取 ID Token...")
            guard let idToken = user.idToken?.tokenString else {
                print("❌ [Google登录] 无法获取 ID Token")
                errorMessage = "Google 登录失败：无法获取令牌"
                isLoading = false
                return
            }
            print("✅ [Google登录] 成功获取 ID Token (长度: \(idToken.count))")

            // 6. 获取 Access Token
            let accessToken = user.accessToken.tokenString
            print("✅ [Google登录] 成功获取 Access Token (长度: \(accessToken.count))")

            // 7. 使用 Supabase 验证 Google 凭证
            print("🔵 [Google登录] 正在向 Supabase 发送验证请求...")
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )

            // 8. 登录成功
            currentUser = session.user
            isAuthenticated = true
            print("✅ [Google登录] Supabase 验证成功！")
            print("✅ [Google登录] 用户 ID: \(session.user.id)")
            print("✅ [Google登录] 用户邮箱: \(session.user.email ?? "未知")")
            print("🎉 [Google登录] Google 登录流程完成！")

        } catch let error as GIDSignInError {
            // Google Sign-In 特定错误处理
            print("❌ [Google登录] GIDSignInError: \(error.localizedDescription)")
            print("❌ [Google登录] 错误代码: \(error.code)")

            switch error.code {
            case .canceled:
                print("ℹ️ [Google登录] 用户取消了登录")
                errorMessage = nil // 用户取消不显示错误
            case .hasNoAuthInKeychain:
                print("❌ [Google登录] Keychain 中没有认证信息")
                errorMessage = "请重新登录 Google 账号"
            default:
                errorMessage = "Google 登录失败: \(error.localizedDescription)"
            }
        } catch {
            // 其他错误（包括 Supabase 错误）
            print("❌ [Google登录] 错误: \(error)")
            print("❌ [Google登录] 错误类型: \(type(of: error))")
            print("❌ [Google登录] 错误描述: \(error.localizedDescription)")
            errorMessage = "Google 登录失败: \(error.localizedDescription)"
        }

        isLoading = false
        print("🔵 [Google登录] 登录流程结束，isLoading = false")
    }

    /// 处理 Google 登录 URL 回调
    /// - Parameter url: 回调 URL
    /// - Returns: 是否成功处理
    @discardableResult
    func handleGoogleSignInURL(_ url: URL) -> Bool {
        print("🔵 [Google登录] 收到 URL 回调: \(url)")
        let handled = GIDSignIn.sharedInstance.handle(url)
        print("🔵 [Google登录] URL 处理结果: \(handled ? "成功" : "失败")")
        return handled
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

    /// 删除账户
    /// - Note: 调用边缘函数删除当前用户账户
    func deleteAccount() async {
        print("🔵 [删除账户] 开始删除账户流程...")
        isLoading = true
        errorMessage = nil

        do {
            // 1. 先检查会话是否有效
            print("🔵 [删除账户] 正在检查会话...")
            let session = try await supabase.auth.session
            print("✅ [删除账户] 会话有效，用户ID: \(session.user.id)")
            print("🔵 [删除账户] Access Token 长度: \(session.accessToken.count)")

            // 2. 调用边缘函数删除账户（显式传递 Authorization header）
            print("🔵 [删除账户] 正在调用边缘函数...")
            try await supabase.functions.invoke(
                "delete-account",
                options: .init(
                    method: .post,
                    headers: [
                        "Authorization": "Bearer \(session.accessToken)"
                    ]
                )
            )

            // 删除成功，清理本地状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false

            print("✅ [删除账户] 账户已成功删除")

        } catch let error as FunctionsError {
            // 处理 Functions 特定错误
            switch error {
            case .httpError(let code, let data):
                let responseBody = String(data: data, encoding: .utf8) ?? "无法解析响应"
                print("❌ [删除账户] HTTP 错误 \(code): \(responseBody)")
                errorMessage = "删除账户失败 (HTTP \(code)): \(responseBody)"
            case .relayError:
                print("❌ [删除账户] Relay 错误")
                errorMessage = "删除账户失败: 网络中继错误"
            @unknown default:
                print("❌ [删除账户] 未知 Functions 错误: \(error)")
                errorMessage = "删除账户失败: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "删除账户失败: \(error.localizedDescription)"
            print("❌ [删除账户] 删除失败: \(error)")
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

// MARK: - Apple Sign In Delegate

/// Apple Sign In 代理类
/// 用于处理 ASAuthorizationController 的回调
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private let continuation: CheckedContinuation<ASAuthorization, Error>

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
        super.init()
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}
