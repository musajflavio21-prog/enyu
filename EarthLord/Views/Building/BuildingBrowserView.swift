
//
//  BuildingBrowserView.swift
//  EarthLord
//
//  建筑浏览器
//  分类筛选建筑模板，选择建造
//

import SwiftUI

/// 建筑浏览器视图
struct BuildingBrowserView: View {

    // MARK: - 属性

    /// 领地数据
    let territory: Territory

    /// 建造完成回调
    var onBuildingPlaced: (() -> Void)?

    // MARK: - 状态对象

    @StateObject private var buildingManager = BuildingManager.shared

    // MARK: - 状态

    /// 选中的分类
    @State private var selectedCategory: BuildingCategory? = nil

    /// 是否显示建造确认页
    @State private var showPlacementView = false

    /// 选中的模板
    @State private var selectedTemplate: BuildingTemplate?

    /// 环境变量
    @Environment(\.dismiss) private var dismiss

    // MARK: - 计算属性

    /// 当前显示的模板
    private var displayedTemplates: [BuildingTemplate] {
        if let category = selectedCategory {
            return buildingManager.templates.filter { $0.category == category }
        }
        return buildingManager.templates
    }

    /// 玩家当前资源
    private var playerResources: [String: Int] {
        buildingManager.getPlayerResources()
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类筛选栏
                categoryFilterBar
                    .padding(.vertical, 12)

                // 建筑网格
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(displayedTemplates) { template in
                            let currentCount = buildingManager.getBuildingCount(templateId: template.id, territoryId: territory.id)
                            let canBuild = checkCanBuild(template: template, currentCount: currentCount)

                            BuildingCard(
                                template: template,
                                canBuild: canBuild,
                                currentCount: currentCount,
                                onTap: {
                                    selectedTemplate = template
                                    // 延迟 0.3s 后打开建造确认页
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        showPlacementView = true
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("建筑浏览器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
            .sheet(isPresented: $showPlacementView) {
                if let template = selectedTemplate {
                    BuildingPlacementView(
                        template: template,
                        territory: territory,
                        onSuccess: {
                            showPlacementView = false
                            onBuildingPlaced?()
                            // 延迟关闭浏览器
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                dismiss()
                            }
                        }
                    )
                }
            }
            .task {
                // 加载背包数据（用于检查资源是否足够）
                await InventoryManager.shared.loadInventory()
                // 加载当前领地的建筑以计算数量
                await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
            }
        }
    }

    // MARK: - 子视图

    /// 分类筛选栏
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 全部分类
                CategoryFilterChip(
                    title: "全部",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                // 各分类
                ForEach(BuildingCategory.allCases, id: \.self) { category in
                    CategoryFilterChip(
                        title: category.displayName,
                        icon: category.iconName,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - 辅助方法

    /// 检查是否可以建造
    private func checkCanBuild(template: BuildingTemplate, currentCount: Int) -> Bool {
        // 检查数量上限
        if currentCount >= template.maxPerTerritory {
            return false
        }

        // 检查资源（简化检查，详细检查在 BuildingPlacementView）
        for (resourceId, required) in template.requiredResources {
            let current = playerResources[resourceId] ?? 0
            if current < required {
                return false
            }
        }

        return true
    }
}

// MARK: - 分类筛选按钮

/// 分类筛选按钮
private struct CategoryFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.green : Color.gray.opacity(0.2))
            )
            .foregroundColor(isSelected ? .black : .white)
        }
    }
}

// MARK: - 预览

#Preview {
    BuildingBrowserView(
        territory: Territory(
            id: "preview",
            userId: "user",
            name: "测试领地",
            path: [["lat": 39.9, "lon": 116.4]],
            area: 5000,
            pointCount: 1,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: nil
        )
    )
}
