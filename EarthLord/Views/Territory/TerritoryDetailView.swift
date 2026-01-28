//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页（全屏地图布局）
//  显示领地地图、建筑列表和操作工具栏
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - 属性

    /// 领地数据
    let territory: Territory

    /// 删除回调
    var onDelete: (() -> Void)?

    // MARK: - 状态对象

    @StateObject private var territoryManager = TerritoryManager.shared
    @StateObject private var buildingManager = BuildingManager.shared

    // MARK: - 状态

    /// 是否显示建筑列表
    @State private var showBuildingList = true

    /// 是否显示建筑浏览器
    @State private var showBuildingBrowser = false

    /// 是否显示建筑详情
    @State private var showBuildingDetail = false

    /// 选中的建筑
    @State private var selectedBuilding: PlayerBuilding?

    /// 是否显示删除确认
    @State private var showDeleteAlert = false

    /// 是否显示重命名弹窗
    @State private var showRenameAlert = false

    /// 新名称输入
    @State private var newName = ""

    /// 是否正在操作
    @State private var isLoading = false

    /// 环境变量
    @Environment(\.dismiss) private var dismiss

    // MARK: - 计算属性

    /// 当前领地的建筑
    private var territoryBuildings: [PlayerBuilding] {
        buildingManager.playerBuildings.filter { $0.territoryId == territory.id }
    }

    // MARK: - 主视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 底层：地图视图
                TerritoryMapView(
                    territory: territory,
                    buildings: territoryBuildings,
                    onSelectBuilding: { building in
                        selectedBuilding = building
                        showBuildingDetail = true
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                // 顶部信息栏
                VStack {
                    topInfoBar
                    Spacer()
                }

                // 底部建筑列表
                VStack {
                    Spacer()
                    buildingListSheet
                }

                // 右下角工具栏
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        TerritoryToolbarView(
                            onAddBuilding: {
                                showBuildingBrowser = true
                            },
                            onEditName: {
                                newName = territory.name ?? ""
                                showRenameAlert = true
                            },
                            onDelete: {
                                showDeleteAlert = true
                            },
                            onLocate: {
                                // 定位到领地中心（已由地图自动处理）
                            }
                        )
                    }
                    .padding(.bottom, showBuildingList ? 280 : 60)
                }

                // 加载遮罩
                if isLoading {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.green)
                }
            }
            // 删除确认弹窗
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task { await deleteTerritory() }
                }
            } message: {
                Text("删除后无法恢复，确认删除这个领地吗？")
            }
            // 重命名弹窗
            .alert("重命名领地", isPresented: $showRenameAlert) {
                TextField("领地名称", text: $newName)
                Button("取消", role: .cancel) {}
                Button("确定") {
                    Task { await renameTerritory() }
                }
            } message: {
                Text("请输入新的领地名称")
            }
            // 建筑浏览器
            .sheet(isPresented: $showBuildingBrowser) {
                BuildingBrowserView(
                    territory: territory,
                    onBuildingPlaced: {
                        // 建筑放置成功后刷新列表
                        Task {
                            await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
                        }
                    }
                )
            }
            // 建筑详情
            .sheet(isPresented: $showBuildingDetail) {
                if let building = selectedBuilding {
                    BuildingDetailView(
                        building: building,
                        onUpdate: {
                            Task {
                                await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
                            }
                        }
                    )
                }
            }
            .task {
                // 加载领地建筑
                await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
            }
        }
    }

    // MARK: - 子视图

    /// 顶部信息栏
    private var topInfoBar: some View {
        HStack(spacing: 16) {
            // 面积信息
            Label(territory.formattedArea, systemImage: "map.fill")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)

            // 建筑数量
            Label("\(territoryBuildings.count) 建筑", systemImage: "building.2.fill")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)

            Spacer()
        }
        .padding()
    }

    /// 底部建筑列表
    private var buildingListSheet: some View {
        VStack(spacing: 0) {
            // 拖动条
            Capsule()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showBuildingList.toggle()
                    }
                }

            // 标题栏
            HStack {
                Text("建筑列表")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showBuildingList.toggle()
                    }
                }) {
                    Image(systemName: showBuildingList ? "chevron.down" : "chevron.up")
                        .foregroundColor(.gray)
                }
            }
            .padding()

            // 建筑列表内容
            if showBuildingList {
                if territoryBuildings.isEmpty {
                    // 空状态
                    VStack(spacing: 12) {
                        Image(systemName: "building.2")
                            .font(.largeTitle)
                            .foregroundColor(.gray.opacity(0.5))

                        Text("还没有建筑")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Button(action: { showBuildingBrowser = true }) {
                            Label("开始建造", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }
                    .frame(height: 150)
                } else {
                    // 建筑列表
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(territoryBuildings) { building in
                                TerritoryBuildingRow(
                                    building: building,
                                    template: buildingManager.getTemplate(byId: building.templateId),
                                    onTapDetail: {
                                        selectedBuilding = building
                                        showBuildingDetail = true
                                    },
                                    onLocate: {
                                        // 定位到建筑位置
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .frame(height: 200)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.9))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - 操作方法

    /// 删除领地
    private func deleteTerritory() async {
        isLoading = true
        let success = await territoryManager.deleteTerritory(territoryId: territory.id)
        isLoading = false

        if success {
            dismiss()
            onDelete?()
        }
    }

    /// 重命名领地
    private func renameTerritory() async {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isLoading = true
        let success = await territoryManager.updateTerritoryName(territoryId: territory.id, newName: newName)
        isLoading = false

        if success {
            // 通知已通过 TerritoryManager 发送
        }
    }
}

// MARK: - 预览

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "preview-id",
            userId: "user-123",
            name: "测试领地",
            path: [
                ["lat": 39.9, "lon": 116.4],
                ["lat": 39.91, "lon": 116.41],
                ["lat": 39.9, "lon": 116.41]
            ],
            area: 5000,
            pointCount: 3,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: "2025-01-07T12:00:00Z"
        )
    )
}
