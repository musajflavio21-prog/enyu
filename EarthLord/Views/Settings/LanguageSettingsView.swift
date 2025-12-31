//
//  LanguageSettingsView.swift
//  EarthLord
//
//  Created by enyu on 2025/12/31.
//

import SwiftUI

/// 语言设置页面
struct LanguageSettingsView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showRestartAlert = false
    @State private var pendingLanguage: AppLanguage?

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    languageRow(language)
                }
            } header: {
                Text("选择语言")
            } footer: {
                Text("切换语言后需要重启应用才能完全生效")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 当前语言信息
            Section {
                HStack {
                    Text("当前语言")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(languageManager.currentLanguage.displayName)
                        .foregroundColor(.primary)
                }

                if languageManager.currentLanguage == .system {
                    HStack {
                        Text("系统语言")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(systemLanguageDisplayName)
                            .foregroundColor(.primary)
                    }
                }
            } header: {
                Text("语言信息")
            }
        }
        .navigationTitle("语言设置")
        .navigationBarTitleDisplayMode(.inline)
        .alert("需要重启应用", isPresented: $showRestartAlert) {
            Button("稍后重启") {
                // 只保存设置，不重启
            }
            Button("立即重启", role: .destructive) {
                // 退出应用，用户重新打开即可
                exit(0)
            }
        } message: {
            Text("语言设置已保存，重启应用后生效")
        }
    }

    // MARK: - 语言选项行

    private func languageRow(_ language: AppLanguage) -> some View {
        Button(action: {
            if languageManager.currentLanguage != language {
                languageManager.currentLanguage = language
                showRestartAlert = true
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.displayName)
                        .font(.body)
                        .foregroundColor(.primary)

                    if language == .system {
                        Text("根据设备系统语言自动切换")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if languageManager.currentLanguage == language {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 辅助属性

    /// 获取系统语言显示名称
    private var systemLanguageDisplayName: String {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        if preferredLanguage.hasPrefix("zh") {
            return "简体中文"
        } else if preferredLanguage.hasPrefix("en") {
            return "English"
        } else {
            return preferredLanguage
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
