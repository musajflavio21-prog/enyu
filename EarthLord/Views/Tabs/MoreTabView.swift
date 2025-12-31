//
//  MoreTabView.swift
//  EarthLord
//
//  Created by enyu on 2025/12/24.
//

import SwiftUI

struct MoreTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        NavigationStack {
            List {
                // 设置区域
                Section {
                    // 语言设置
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("语言设置")
                                    .font(.body)
                                Text(languageManager.currentLanguage.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // 通用设置（占位）
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .frame(width: 32)

                        Text("通用设置")
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                    .foregroundColor(.secondary)
                } header: {
                    Text("设置")
                }

                // 开发工具区域
                Section {
                    NavigationLink {
                        SupabaseTestView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Supabase 连接测试")
                                    .font(.body)
                                Text("检测后端服务连接状态")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("开发工具")
                }

                // 其他区域
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .frame(width: 32)

                        Text("关于")
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                    .foregroundColor(.secondary)
                } header: {
                    Text("其他")
                }

                // 登出按钮
                Section {
                    Button(action: {
                        Task {
                            await authManager.signOut()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title2)
                                .foregroundColor(.red)
                                .frame(width: 32)

                            Text("退出登录")
                                .font(.body)
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("更多")
        }
    }
}

#Preview {
    MoreTabView()
        .environmentObject(AuthManager.shared)
}
