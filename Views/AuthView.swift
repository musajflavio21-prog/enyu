//
//  AuthView.swift
//  EarthLord
//
//  Created by enyu on 2025/12/24.
//

import SwiftUI

/// 认证页面
/// 包含登录、注册、找回密码功能
struct AuthView: View {

    // MARK: - 状态

    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 当前选中的Tab（0: 登录, 1: 注册）
    @State private var selectedTab = 0

    /// 是否显示忘记密码弹窗
    @State private var showForgotPassword = false

    /// 是否显示Toast
    @State private var showToast = false
    @State private var toastMessage = ""

    // MARK: - 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    // MARK: - 注册表单
    @State private var registerEmail = ""
    @State private var registerOTP = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""
    @State private var registerStep = 1  // 1: 邮箱, 2: 验证码, 3: 设置密码

    // MARK: - 找回密码表单
    @State private var resetEmail = ""
    @State private var resetOTP = ""
    @State private var resetPassword = ""
    @State private var resetConfirmPassword = ""
    @State private var resetStep = 1  // 1: 邮箱, 2: 验证码, 3: 新密码

    // MARK: - 倒计时
    @State private var countdown = 0
    @State private var countdownTimer: Timer?

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            ScrollView {
                VStack(spacing: 30) {
                    // Logo 区域
                    logoSection
                        .padding(.top, 60)

                    // Tab 切换
                    tabSelector

                    // 内容区域
                    if selectedTab == 0 {
                        loginView
                    } else {
                        registerView
                    }

                    // 分隔线
                    dividerSection

                    // 第三方登录
                    socialLoginSection

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 24)
            }

            // 加载遮罩
            if authManager.isLoading {
                loadingOverlay
            }

            // Toast
            if showToast {
                toastView
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onChange(of: authManager.otpVerified) { _, verified in
            // OTP验证成功后自动进入下一步
            if verified && authManager.needsPasswordSetup {
                if selectedTab == 1 {
                    registerStep = 3
                }
            }
        }
        .onChange(of: authManager.errorMessage) { _, error in
            // 显示错误Toast
            if let error = error, !error.isEmpty {
                showToastMessage(error)
            }
        }
    }

    // MARK: - 背景渐变

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.10, green: 0.10, blue: 0.18),
                Color(red: 0.09, green: 0.13, blue: 0.24),
                Color(red: 0.06, green: 0.06, blue: 0.10)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Logo 区域

    private var logoSection: some View {
        VStack(spacing: 12) {
            // Logo 圆形背景
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primary.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 15)

                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            // 标题
            Text("地球新主")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("EARTH LORD")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .tracking(3)
        }
    }

    // MARK: - Tab 选择器

    private var tabSelector: some View {
        HStack(spacing: 0) {
            // 登录Tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 0
                    authManager.resetFlowState()
                    resetRegisterForm()
                }
            } label: {
                Text("登录")
                    .font(.headline)
                    .foregroundColor(selectedTab == 0 ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == 0 ?
                        ApocalypseTheme.primary.opacity(0.1) :
                        Color.clear
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(selectedTab == 0 ? ApocalypseTheme.primary : Color.clear),
                        alignment: .bottom
                    )
            }

            // 注册Tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 1
                    authManager.resetFlowState()
                    resetLoginForm()
                }
            } label: {
                Text("注册")
                    .font(.headline)
                    .foregroundColor(selectedTab == 1 ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == 1 ?
                        ApocalypseTheme.primary.opacity(0.1) :
                        Color.clear
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(selectedTab == 1 ? ApocalypseTheme.primary : Color.clear),
                        alignment: .bottom
                    )
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
    }

    // MARK: - 登录视图

    private var loginView: some View {
        VStack(spacing: 16) {
            // 邮箱输入框
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入框
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $loginPassword
            )

            // 登录按钮
            PrimaryButton(title: "登录") {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)

            // 忘记密码
            Button {
                showForgotPassword = true
                resetStep = 1
                resetEmail = ""
                resetOTP = ""
                resetPassword = ""
                resetConfirmPassword = ""
                authManager.resetFlowState()
            } label: {
                Text("忘记密码？")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.info)
            }
        }
    }

    // MARK: - 注册视图

    private var registerView: some View {
        VStack(spacing: 16) {
            // 步骤指示器
            stepIndicator(currentStep: registerStep, totalSteps: 3)

            switch registerStep {
            case 1:
                registerStep1View
            case 2:
                registerStep2View
            case 3:
                registerStep3View
            default:
                EmptyView()
            }
        }
    }

    // 注册第一步：邮箱
    private var registerStep1View: some View {
        VStack(spacing: 16) {
            Text("输入你的邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            PrimaryButton(title: "发送验证码") {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        registerStep = 2
                        startCountdown()
                    }
                }
            }
            .disabled(registerEmail.isEmpty || !isValidEmail(registerEmail))
        }
    }

    // 注册第二步：验证码
    private var registerStep2View: some View {
        VStack(spacing: 16) {
            Text("输入验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证码已发送至 \(registerEmail)")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 6位验证码输入
            CustomTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $registerOTP,
                keyboardType: .numberPad
            )

            PrimaryButton(title: "验证") {
                Task {
                    await authManager.verifyRegisterOTP(email: registerEmail, code: registerOTP)
                }
            }
            .disabled(registerOTP.count != 6)

            // 重发验证码
            HStack {
                if countdown > 0 {
                    Text("\(countdown)秒后可重新发送")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else {
                    Button {
                        Task {
                            await authManager.sendRegisterOTP(email: registerEmail)
                            if authManager.otpSent {
                                startCountdown()
                            }
                        }
                    } label: {
                        Text("重新发送验证码")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.info)
                    }
                }
            }

            // 返回上一步
            Button {
                registerStep = 1
                authManager.resetFlowState()
            } label: {
                Text("返回修改邮箱")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    // 注册第三步：设置密码
    private var registerStep3View: some View {
        VStack(spacing: 16) {
            Text("设置登录密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("请设置一个安全的密码以完成注册")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码（至少6位）",
                text: $registerPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerConfirmPassword
            )

            // 密码匹配提示
            if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            PrimaryButton(title: "完成注册") {
                Task {
                    await authManager.completeRegistration(password: registerPassword)
                }
            }
            .disabled(
                registerPassword.count < 6 ||
                registerPassword != registerConfirmPassword
            )
        }
    }

    // MARK: - 忘记密码弹窗

    private var forgotPasswordSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 步骤指示器
                        stepIndicator(currentStep: resetStep, totalSteps: 3)
                            .padding(.top, 20)

                        switch resetStep {
                        case 1:
                            resetStep1View
                        case 2:
                            resetStep2View
                        case 3:
                            resetStep3View
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // 加载遮罩
                if authManager.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showForgotPassword = false
                        authManager.resetFlowState()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .onChange(of: authManager.otpVerified) { _, verified in
            if verified && authManager.needsPasswordSetup && showForgotPassword {
                resetStep = 3
            }
        }
    }

    // 找回密码第一步
    private var resetStep1View: some View {
        VStack(spacing: 16) {
            Text("输入注册邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $resetEmail,
                keyboardType: .emailAddress
            )

            PrimaryButton(title: "发送验证码") {
                Task {
                    await authManager.sendResetOTP(email: resetEmail)
                    if authManager.otpSent {
                        resetStep = 2
                        startCountdown()
                    }
                }
            }
            .disabled(resetEmail.isEmpty || !isValidEmail(resetEmail))
        }
    }

    // 找回密码第二步
    private var resetStep2View: some View {
        VStack(spacing: 16) {
            Text("输入验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证码已发送至 \(resetEmail)")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $resetOTP,
                keyboardType: .numberPad
            )

            PrimaryButton(title: "验证") {
                Task {
                    await authManager.verifyResetOTP(email: resetEmail, code: resetOTP)
                }
            }
            .disabled(resetOTP.count != 6)

            // 重发验证码
            HStack {
                if countdown > 0 {
                    Text("\(countdown)秒后可重新发送")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else {
                    Button {
                        Task {
                            await authManager.sendResetOTP(email: resetEmail)
                            if authManager.otpSent {
                                startCountdown()
                            }
                        }
                    } label: {
                        Text("重新发送验证码")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.info)
                    }
                }
            }
        }
    }

    // 找回密码第三步
    private var resetStep3View: some View {
        VStack(spacing: 16) {
            Text("设置新密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $resetPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $resetConfirmPassword
            )

            // 密码匹配提示
            if !resetConfirmPassword.isEmpty && resetPassword != resetConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            PrimaryButton(title: "重置密码") {
                Task {
                    await authManager.resetPassword(newPassword: resetPassword)
                    if authManager.isAuthenticated {
                        showForgotPassword = false
                    }
                }
            }
            .disabled(
                resetPassword.count < 6 ||
                resetPassword != resetConfirmPassword
            )
        }
    }

    // MARK: - 分隔线

    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(ApocalypseTheme.textMuted)
                .frame(height: 1)

            Text("或者使用以下方式登录")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .fixedSize()

            Rectangle()
                .fill(ApocalypseTheme.textMuted)
                .frame(height: 1)
        }
        .padding(.top, 20)
    }

    // MARK: - 第三方登录

    private var socialLoginSection: some View {
        VStack(spacing: 12) {
            // Apple 登录按钮
            Button {
                showToastMessage("Apple 登录即将开放")
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("通过 Apple 登录")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.black)
                .cornerRadius(10)
            }

            // Google 登录按钮
            Button {
                showToastMessage("Google 登录即将开放")
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    Text("通过 Google 登录")
                        .font(.headline)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .cornerRadius(10)
            }
        }
    }

    // MARK: - 步骤指示器

    private func stepIndicator(currentStep: Int, totalSteps: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(width: 10, height: 10)

                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        .frame(width: 30, height: 2)
                }
            }
        }
    }

    // MARK: - 加载遮罩

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)

                Text("请稍候...")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(30)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Toast

    private var toastView: some View {
        VStack {
            Spacer()

            Text(toastMessage)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: showToast)
    }

    // MARK: - 辅助方法

    /// 显示Toast消息
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
            authManager.clearError()
        }
    }

    /// 开始倒计时
    private func startCountdown() {
        countdown = 60
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    /// 验证邮箱格式
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// 重置登录表单
    private func resetLoginForm() {
        loginEmail = ""
        loginPassword = ""
    }

    /// 重置注册表单
    private func resetRegisterForm() {
        registerEmail = ""
        registerOTP = ""
        registerPassword = ""
        registerConfirmPassword = ""
        registerStep = 1
    }
}

// MARK: - 自定义组件

/// 自定义输入框
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ApocalypseTheme.textMuted, lineWidth: 1)
        )
    }
}

/// 自定义密码输入框
struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isSecure = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 24)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            Button {
                isSecure.toggle()
            } label: {
                Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ApocalypseTheme.textMuted, lineWidth: 1)
        )
    }
}

/// 主按钮
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    isEnabled ?
                    ApocalypseTheme.primary :
                    ApocalypseTheme.textMuted
                )
                .cornerRadius(10)
        }
    }
}

#Preview {
    AuthView()
}
