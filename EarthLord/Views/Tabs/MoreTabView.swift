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
                // 社交功能区域
                Section {
                    // 聊天
                    NavigationLink {
                        ChatView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("聊天")
                                    .font(.body)
                                Text("公共频道与附近玩家")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // 排行榜
                    NavigationLink {
                        LeaderboardView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                                .font(.title2)
                                .foregroundColor(.yellow)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("排行榜")
                                    .font(.body)
                                Text("查看各类排名")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // 成就
                    NavigationLink {
                        AchievementView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("成就")
                                    .font(.body)
                                Text("查看成就进度")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("社交")
                }

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
                        TestMenuView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "hammer.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("开发测试")
                                    .font(.body)
                                Text("Supabase 和圈地功能测试")
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
