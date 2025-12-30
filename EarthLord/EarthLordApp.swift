//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by Zhuanz密码0000 on 2025/12/23.
//

import SwiftUI

@main
struct EarthLordApp: App {
    /// 认证管理器（全局状态）
    @StateObject private var authManager = AuthManager.shared

    /// 是否显示启动画面
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 根据认证状态显示不同页面
                if showSplash {
                    // 启动画面
                    SplashView(isFinished: $showSplash)
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
            .animation(.easeInOut(duration: 0.3), value: showSplash)
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        }
    }
}
