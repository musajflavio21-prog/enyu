//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by Zhuanz密码0000 on 2025/12/23.
//

import SwiftUI
import GoogleSignIn

@main
struct EarthLordApp: App {
    /// 认证管理器（全局状态）
    @StateObject private var authManager = AuthManager.shared

    /// 启动画面是否已完成
    @State private var splashFinished = false

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
                } else {
                    // 未登录：显示认证页面
                    AuthView()
                        .transition(.opacity)
                        .environmentObject(authManager)
                }
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
