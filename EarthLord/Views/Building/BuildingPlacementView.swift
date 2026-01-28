//
//  BuildingPlacementView.swift
//  EarthLord
//
//  建造确认页
//  显示建筑详情、资源需求检查、位置选择
//

import SwiftUI
import CoreLocation

/// 建造确认视图
struct BuildingPlacementView: View {

    // MARK: - 属性

    /// 建筑模板
    let template: BuildingTemplate

    /// 领地数据
    let territory: Territory

    /// 建造成功回调
    var onSuccess: (() -> Void)?

    // MARK: - 状态对象

    @StateObject private var buildingManager = BuildingManager.shared

    // MARK: - 状态

    /// 选中的位置
    @State private var selectedLocation: CLLocationCoordinate2D?

    /// 是否显示位置选择器
    @State private var showLocationPicker = false

    /// 是否正在建造
    @State private var isBuilding = false

    /// 错误消息
    @State private var errorMessage: String?

    /// 是否显示错误弹窗
    @State private var showError = false

    /// 环境变量
    @Environment(\.dismiss) private var dismiss

    // MARK: - 计算属性

    /// 玩家当前资源
    private var playerResources: [String: Int] {
        buildingManager.getPlayerResources()
    }

    /// 是否资源足够
    private var hasEnoughResources: Bool {
        for (resourceId, required) in template.requiredResources {
            let current = playerResources[resourceId] ?? 0
            if current < required {
                return false
            }
        }
        return true
    }

    /// 是否可以建造
    private var canBuild: Bool {
        hasEnoughResources
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 建筑信息卡片
                    buildingInfoCard

                    // 资源需求
                    resourceRequirementSection

                    // 位置选择（可选）
                    locationSelectionSection

                    // 建造按钮
                    buildButton
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("建造确认")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
            .alert("建造失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .sheet(isPresented: $showLocationPicker) {
                BuildingLocationPickerView(
                    territory: territory,
                    template: template,
                    onConfirm: { location in
                        selectedLocation = location
                    },
                    onCancel: {
                        // 取消选择
                    }
                )
            }
        }
    }

    // MARK: - 子视图

    /// 建筑信息卡片
    private var buildingInfoCard: some View {
        VStack(spacing: 16) {
            // 图标和名称
            HStack(spacing: 16) {
                Image(systemName: template.iconName)
                    .font(.largeTitle)
                    .foregroundColor(.green)
                    .frame(width: 60, height: 60)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        // 分类
                        Label(template.category.displayName, systemImage: template.category.iconName)
                            .font(.caption)
                            .foregroundColor(.gray)

                        // 层级
                        Text("T\(template.tier)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(4)
                    }
                }

                Spacer()
            }

            // 描述
            Text(template.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(Color.gray.opacity(0.3))

            // 建造信息
            HStack {
                // 建造时间
                VStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    Text(template.formattedBuildTime)
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("建造时间")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)
                    .background(Color.gray.opacity(0.3))

                // 最高等级
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle")
                        .foregroundColor(.blue)
                    Text("Lv.\(template.maxLevel)")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("最高等级")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)
                    .background(Color.gray.opacity(0.3))

                // 数量上限
                VStack(spacing: 4) {
                    Image(systemName: "square.stack")
                        .foregroundColor(.purple)
                    Text("\(template.maxPerTerritory)")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("数量上限")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(16)
    }

    /// 资源需求区域
    private var resourceRequirementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("所需资源")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                if hasEnoughResources {
                    Label("资源充足", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("资源不足", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resourceId in
                    let required = template.requiredResources[resourceId] ?? 0
                    let current = playerResources[resourceId] ?? 0

                    ResourceRow(resourceId: resourceId, required: required, current: current)

                    if resourceId != template.requiredResources.keys.sorted().last {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
    }

    /// 位置选择区域
    private var locationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("建筑位置")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("(可选)")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()
            }

            Button(action: { showLocationPicker = true }) {
                HStack {
                    Image(systemName: selectedLocation != nil ? "mappin.circle.fill" : "mappin.circle")
                        .font(.title2)
                        .foregroundColor(selectedLocation != nil ? .green : .gray)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedLocation != nil ? "已选择位置" : "点击选择位置")
                            .font(.subheadline)
                            .foregroundColor(.white)

                        if let location = selectedLocation {
                            Text(String(format: "%.5f, %.5f", location.latitude, location.longitude))
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("可在地图上指定建筑位置")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    /// 建造按钮
    private var buildButton: some View {
        Button(action: { Task { await startBuilding() } }) {
            HStack {
                if isBuilding {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "hammer.fill")
                    Text("开始建造")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canBuild ? Color.green : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canBuild || isBuilding)
    }

    // MARK: - 操作方法

    /// 开始建造
    private func startBuilding() async {
        isBuilding = true

        let location: (lat: Double, lon: Double)?
        if let coord = selectedLocation {
            location = (lat: coord.latitude, lon: coord.longitude)
        } else {
            location = nil
        }

        let result = await buildingManager.startConstruction(
            templateId: template.id,
            territoryId: territory.id,
            location: location
        )

        isBuilding = false

        switch result {
        case .success:
            onSuccess?()
            dismiss()
        case .failure(let error):
            errorMessage = error.errorDescription
            showError = true
        }
    }
}

// MARK: - 预览

#Preview {
    BuildingPlacementView(
        template: BuildingTemplate(
            id: "campfire",
            name: "篝火",
            description: "基础生存设施，提供温暖和烹饪功能。夜间可作为照明。",
            category: .survival,
            tier: 1,
            maxLevel: 3,
            buildTimeSeconds: 30,
            requiredResources: ["wood": 30, "stone": 20],
            maxPerTerritory: 2,
            iconName: "flame.fill",
            effect: nil
        ),
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
