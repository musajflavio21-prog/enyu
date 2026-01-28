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

    @State private var isAddingResources = false
    @State private var resourcesAdded = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        List {
            #if DEBUG
            // 建造系统测试资源
            Section {
                Button(action: {
                    Task {
                        await addTestResources()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "cube.box.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("添加测试资源")
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("木材200、石头150、金属100、玻璃50")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        Spacer()

                        if isAddingResources {
                            ProgressView()
                        } else if resourcesAdded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .disabled(isAddingResources)
                .listRowBackground(ApocalypseTheme.cardBackground)

                Button(action: {
                    Task {
                        await clearAllResources()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("清空背包")
                                .font(.body)
                                .foregroundColor(.red)

                            Text("删除所有背包物品")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(ApocalypseTheme.cardBackground)
            } header: {
                Text("建造系统测试")
            }
            #endif

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
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - 测试方法

    #if DEBUG
    private func addTestResources() async {
        isAddingResources = true
        resourcesAdded = false

        let success = await InventoryManager.shared.addTestResources()

        isAddingResources = false

        if success {
            resourcesAdded = true
            alertMessage = "测试资源添加成功！\n木材200、石头150、金属100、玻璃50"
        } else {
            alertMessage = "添加测试资源失败，请检查网络连接"
        }
        showAlert = true
    }

    private func clearAllResources() async {
        let success = await InventoryManager.shared.clearAllItems()

        if success {
            alertMessage = "背包已清空"
        } else {
            alertMessage = "清空背包失败"
        }
        showAlert = true
    }
    #endif
}

// MARK: - 预览

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
