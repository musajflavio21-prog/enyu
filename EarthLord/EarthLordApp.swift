//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by Zhuanz密码0000 on 2025/12/23.
//

import SwiftUI
import GoogleSignIn
import Combine

@main
struct EarthLordApp: App {
    /// 认证管理器（全局状态）
    @StateObject private var authManager = AuthManager.shared

    /// 定位管理器（全局状态）
    @StateObject private var locationManager = LocationManager.shared

    /// 启动画面是否已完成
    @State private var splashFinished = false

    /// 当前语言（用于触发视图刷新）
    @State private var currentLanguage: AppLanguage = LanguageManager.shared.currentLanguage

    /// 根据语言设置返回对应的 Locale
    private func localeForLanguage(_ language: AppLanguage) -> Locale {
        switch language {
        case .system:
            // 跟随系统：使用系统首选语言
            return Locale.current
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .en:
            return Locale(identifier: "en")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 根据认证状态显示不同页面
                if !splashFinished {
                    // 启动画面
                    SplashView(isFinished: $splashFinished)
                        .transition(.opacity)
                } else if authManager.isAuthenticated {
                    // 已登录：显示主界面
                    MainTabView()
                        .transition(.opacity)
                        .environmentObject(authManager)
                        .environmentObject(locationManager)
                } else {
                    // 未登录：显示认证页面
                    AuthView()
                        .transition(.opacity)
                        .environmentObject(authManager)
                }
            }
            // 当语言变化时强制刷新整个视图树
            .id(currentLanguage)
            .environment(\.locale, localeForLanguage(currentLanguage))
            .onReceive(LanguageManager.shared.$currentLanguage) { newLanguage in
                currentLanguage = newLanguage
            }
            .animation(.easeInOut(duration: 0.3), value: splashFinished)
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            // 处理 URL 回调（Google Sign-In）
            .onOpenURL { url in
                print("🔵 [App] 收到 URL 回调: \(url)")
                print("🔵 [App] URL Scheme: \(url.scheme ?? "无")")
                print("🔵 [App] URL Host: \(url.host ?? "无")")

                // 尝试让 Google Sign-In 处理 URL
                let handled = GIDSignIn.sharedInstance.handle(url)
                print("🔵 [App] Google Sign-In 处理结果: \(handled ? "已处理" : "未处理")")
            }
        }
    }
}
