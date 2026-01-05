//
//  TestMenuView.swift
//  EarthLord
//
//  测试模块入口菜单
//  提供 Supabase 测试和圈地测试的入口
//

import SwiftUI

/// 测试模块入口菜单
/// 注意：不需要套 NavigationStack，因为它已经在 ContentView 的 NavigationStack 内部
struct TestMenuView: View {

    var body: some View {
        List {
            // Supabase 连接测试
            NavigationLink(destination: SupabaseTestView()) {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Supabase 连接测试")
                            .font(.body)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("测试数据库连接和认证")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(ApocalypseTheme.cardBackground)

            // 圈地功能测试
            NavigationLink(destination: TerritoryTestView()) {
                HStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("圈地功能测试")
                            .font(.body)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("查看圈地模块运行日志")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(ApocalypseTheme.cardBackground)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ApocalypseTheme.background)
        .navigationTitle("开发测试")
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
