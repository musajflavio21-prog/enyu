//
//  TerritoryBuildingRow.swift
//  EarthLord
//
//  领地建筑行组件
//  显示建筑信息，包含建造进度和操作菜单
//

import SwiftUI

/// 领地建筑行视图
struct TerritoryBuildingRow: View {

    // MARK: - 属性

    /// 玩家建筑
    let building: PlayerBuilding

    /// 建筑模板
    let template: BuildingTemplate?

    /// 点击查看详情回调
    var onTapDetail: (() -> Void)?

    /// 点击定位回调
    var onLocate: (() -> Void)?

    // MARK: - 状态

    /// 定时器触发器（用于刷新进度）
    @State private var timerTrigger = false

    /// 定时器
    @State private var timer: Timer?

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 12) {
            // 左侧图标
            buildingIcon

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                // 名称和等级
                HStack {
                    Text(building.buildingName)
                        .font(.headline)
                        .foregroundColor(.white)

                    if building.status == .active {
                        Text("Lv.\(building.level)")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                // 状态或进度
                if building.status == .constructing, let template = template {
                    // 建造中显示进度
                    buildingProgressView(template: template)
                } else {
                    // 运行中显示分类
                    HStack(spacing: 8) {
                        Label(template?.category.displayName ?? "未知", systemImage: template?.category.iconName ?? "questionmark")
                            .font(.caption)
                            .foregroundColor(.gray)

                        if building.coordinate != nil {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }

            Spacer()

            // 右侧操作
            Menu {
                Button(action: { onTapDetail?() }) {
                    Label("查看详情", systemImage: "info.circle")
                }

                if building.coordinate != nil {
                    Button(action: { onLocate?() }) {
                        Label("定位", systemImage: "location")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
        .onAppear {
            startTimerIfNeeded()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - 子视图

    /// 建筑图标
    private var buildingIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(statusColor.opacity(0.2))
                .frame(width: 50, height: 50)

            if building.status == .constructing {
                // 建造中显示旋转动画
                Image(systemName: template?.iconName ?? "hammer.fill")
                    .font(.title2)
                    .foregroundColor(statusColor)
                    .opacity(0.5)

                ProgressView()
                    .tint(statusColor)
                    .scaleEffect(0.8)
            } else {
                Image(systemName: template?.iconName ?? "building.2.fill")
                    .font(.title2)
                    .foregroundColor(statusColor)
            }
        }
    }

    /// 建造进度视图
    private func buildingProgressView(template: BuildingTemplate) -> some View {
        let _ = timerTrigger // 触发重新计算
        let progress = building.buildProgress(template: template)
        let remainingTime = building.formattedRemainingTime(template: template)

        return VStack(alignment: .leading, spacing: 4) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)

            // 剩余时间
            HStack {
                Text("建造中")
                    .font(.caption)
                    .foregroundColor(.blue)

                Spacer()

                Text(remainingTime)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 辅助属性

    /// 状态颜色
    private var statusColor: Color {
        switch building.status {
        case .constructing: return .blue
        case .active: return .green
        }
    }

    // MARK: - 定时器

    /// 启动定时器（如果正在建造）
    private func startTimerIfNeeded() {
        guard building.status == .constructing else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timerTrigger.toggle()
        }
    }

    /// 停止定时器
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 12) {
        TerritoryBuildingRow(
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
            ),
            template: BuildingTemplate(
                id: "campfire",
                name: "篝火",
                description: "基础生存设施",
                category: .survival,
                tier: 1,
                maxLevel: 3,
                buildTimeSeconds: 30,
                requiredResources: ["wood": 30],
                maxPerTerritory: 2,
                iconName: "flame.fill",
                effect: nil
            )
        )

        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: UUID(),
                userId: UUID(),
                territoryId: "test",
                templateId: "shelter",
                buildingName: "庇护所",
                status: .constructing,
                level: 1,
                locationLat: nil,
                locationLon: nil,
                buildStartedAt: Date().addingTimeInterval(-15),
                buildCompletedAt: nil,
                createdAt: Date(),
                updatedAt: nil
            ),
            template: BuildingTemplate(
                id: "shelter",
                name: "庇护所",
                description: "简易住所",
                category: .survival,
                tier: 1,
                maxLevel: 5,
                buildTimeSeconds: 60,
                requiredResources: ["wood": 50],
                maxPerTerritory: 1,
                iconName: "house.fill",
                effect: nil
            )
        )
    }
    .padding()
    .background(Color.black)
}
