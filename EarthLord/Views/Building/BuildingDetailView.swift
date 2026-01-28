//
//  BuildingDetailView.swift
//  EarthLord
//
//  建筑详情页
//  显示建筑信息、升级和拆除功能
//

import SwiftUI
import CoreLocation

/// 建筑详情视图
struct BuildingDetailView: View {

    // MARK: - 属性

    /// 玩家建筑
    let building: PlayerBuilding

    /// 更新回调
    var onUpdate: (() -> Void)?

    // MARK: - 状态对象

    @StateObject private var buildingManager = BuildingManager.shared

    // MARK: - 状态

    /// 是否显示拆除确认
    @State private var showDemolishAlert = false

    /// 是否显示升级确认
    @State private var showUpgradeAlert = false

    /// 是否正在操作
    @State private var isLoading = false

    /// 错误消息
    @State private var errorMessage: String?

    /// 是否显示错误弹窗
    @State private var showError = false

    /// 定时器触发器（用于刷新进度）
    @State private var timerTrigger = false

    /// 定时器
    @State private var timer: Timer?

    /// 环境变量
    @Environment(\.dismiss) private var dismiss

    // MARK: - 计算属性

    /// 建筑模板
    private var template: BuildingTemplate? {
        buildingManager.getTemplate(byId: building.templateId)
    }

    /// 升级所需资源
    private var upgradeCost: [String: Int]? {
        buildingManager.getUpgradeCost(for: building)
    }

    /// 是否可以升级
    private var canUpgrade: Bool {
        guard building.status == .active,
              let template = template,
              building.level < template.maxLevel,
              let cost = upgradeCost else {
            return false
        }

        let resources = buildingManager.getPlayerResources()
        for (resourceId, required) in cost {
            if (resources[resourceId] ?? 0) < required {
                return false
            }
        }
        return true
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 建筑状态卡片
                    statusCard

                    // 建筑信息
                    if let template = template {
                        buildingInfoSection(template: template)
                    }

                    // 建造进度（如果建造中）
                    if building.status == .constructing, let template = template {
                        constructionProgressSection(template: template)
                    }

                    // 升级区域（如果已完成）
                    if building.status == .active {
                        upgradeSection
                    }

                    // 拆除按钮
                    demolishButton
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("建筑详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.green)
                }
            }
            // 拆除确认
            .alert("确认拆除", isPresented: $showDemolishAlert) {
                Button("取消", role: .cancel) {}
                Button("拆除", role: .destructive) {
                    Task { await demolishBuilding() }
                }
            } message: {
                Text("拆除后无法恢复，确认拆除这个建筑吗？")
            }
            // 升级确认
            .alert("确认升级", isPresented: $showUpgradeAlert) {
                Button("取消", role: .cancel) {}
                Button("升级") {
                    Task { await upgradeBuilding() }
                }
            } message: {
                if let cost = upgradeCost {
                    let costText = cost.map { "\(resourceName(for: $0.key)) x\($0.value)" }.joined(separator: ", ")
                    Text("升级到 Lv.\(building.level + 1) 需要消耗：\(costText)")
                } else {
                    Text("确认升级？")
                }
            }
            // 错误弹窗
            .alert("操作失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .onAppear {
                startTimerIfNeeded()
            }
            .onDisappear {
                stopTimer()
            }
        }
    }

    // MARK: - 子视图

    /// 状态卡片
    private var statusCard: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 70, height: 70)

                if building.status == .constructing {
                    ProgressView()
                        .tint(statusColor)
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: template?.iconName ?? "building.2.fill")
                        .font(.title)
                        .foregroundColor(statusColor)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(building.buildingName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    // 状态
                    Label(building.status.displayName, systemImage: building.status == .constructing ? "hammer.fill" : "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(statusColor)

                    // 等级
                    if building.status == .active {
                        Text("Lv.\(building.level)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.3))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(16)
    }

    /// 建筑信息区域
    private func buildingInfoSection(template: BuildingTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建筑信息")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                InfoRow(icon: "tag.fill", label: "分类", value: template.category.displayName)
                InfoRow(icon: "arrow.up.circle.fill", label: "最高等级", value: "Lv.\(template.maxLevel)")

                if let coordinate = building.coordinate {
                    InfoRow(
                        icon: "location.fill",
                        label: "位置",
                        value: String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
                    )
                }

                if let effect = template.effect {
                    InfoRow(icon: "sparkles", label: "效果", value: "\(effect.type): \(Int(effect.value))\(effect.unit ?? "")")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
    }

    /// 建造进度区域
    private func constructionProgressSection(template: BuildingTemplate) -> some View {
        let _ = timerTrigger // 触发重新计算
        let progress = building.buildProgress(template: template)
        let remainingTime = building.formattedRemainingTime(template: template)

        return VStack(alignment: .leading, spacing: 12) {
            Text("建造进度")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 16) {
                // 进度条
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * progress, height: 8)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.blue)

                        Spacer()

                        Text("剩余 \(remainingTime)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .monospacedDigit()
                    }
                }

                // 建造时间信息
                HStack {
                    Label("总时长", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Text(template.formattedBuildTime)
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
    }

    /// 升级区域
    private var upgradeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("升级")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                if let template = template, building.level >= template.maxLevel {
                    Text("已达最高等级")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if let cost = upgradeCost {
                VStack(spacing: 12) {
                    // 升级到下一级
                    HStack {
                        Text("升级到")
                            .foregroundColor(.gray)

                        Text("Lv.\(building.level + 1)")
                            .fontWeight(.bold)
                            .foregroundColor(.green)

                        Spacer()
                    }
                    .font(.subheadline)

                    Divider()
                        .background(Color.gray.opacity(0.3))

                    // 所需资源
                    ForEach(Array(cost.keys.sorted()), id: \.self) { resourceId in
                        let required = cost[resourceId] ?? 0
                        let current = buildingManager.getPlayerResources()[resourceId] ?? 0

                        ResourceRow(resourceId: resourceId, required: required, current: current)
                    }

                    // 升级按钮
                    Button(action: { showUpgradeAlert = true }) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("升级")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canUpgrade ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!canUpgrade)
                }
                .padding()
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)
            } else {
                Text("已达最高等级，无法继续升级")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
            }
        }
    }

    /// 拆除按钮
    private var demolishButton: some View {
        Button(action: { showDemolishAlert = true }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "trash.fill")
                    Text("拆除建筑")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }

    // MARK: - 辅助属性

    /// 状态颜色
    private var statusColor: Color {
        switch building.status {
        case .constructing: return .blue
        case .active: return .green
        }
    }

    /// 资源名称
    private func resourceName(for resourceId: String) -> String {
        switch resourceId {
        // UUID 映射
        case "79d5cc71-d98a-46ef-9a4b-4a7d7c1c0495": return "木材"
        case "419e6e21-dc02-4bd4-94bb-1fcb9c08f738": return "石头"
        case "dd722a71-ba35-4cf8-92d3-356bc10f0b35": return "金属"
        case "de93eab2-daa0-43dc-b33a-1f21496ebc31": return "玻璃"
        // 保留旧的简单字符串映射以兼容
        case "wood": return "木材"
        case "stone": return "石头"
        case "metal": return "金属"
        case "glass": return "玻璃"
        default: return resourceId
        }
    }

    // MARK: - 定时器

    private func startTimerIfNeeded() {
        guard building.status == .constructing else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timerTrigger.toggle()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - 操作方法

    /// 升级建筑
    private func upgradeBuilding() async {
        isLoading = true

        let result = await buildingManager.upgradeBuilding(buildingId: building.id)

        isLoading = false

        switch result {
        case .success:
            onUpdate?()
            dismiss()
        case .failure(let error):
            errorMessage = error.errorDescription
            showError = true
        }
    }

    /// 拆除建筑
    private func demolishBuilding() async {
        isLoading = true

        let result = await buildingManager.deleteBuilding(buildingId: building.id)

        isLoading = false

        switch result {
        case .success:
            onUpdate?()
            dismiss()
        case .failure(let error):
            errorMessage = error.errorDescription
            showError = true
        }
    }
}

// MARK: - 信息行视图

/// 信息行组件
private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)

            Text(label)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)

            Spacer()

            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 预览

#Preview {
    BuildingDetailView(
        building: PlayerBuilding(
            id: UUID(),
            userId: UUID(),
            territoryId: "test",
            templateId: "campfire",
            buildingName: "篝火",
            status: .active,
            level: 2,
            locationLat: 39.9,
            locationLon: 116.4,
            buildStartedAt: Date().addingTimeInterval(-60),
            buildCompletedAt: Date(),
            createdAt: Date(),
            updatedAt: nil
        )
    )
}
