//
//  TerritoryTabView.swift
//  EarthLord
//
//  领地管理 Tab 页面
//  显示我的领地列表、统计信息和详情管理
//

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - 状态属性

    /// 领地管理器
    @StateObject private var territoryManager = TerritoryManager.shared

    /// 我的领地列表
    @State private var myTerritories: [Territory] = []

    /// 选中的领地（用于展示详情页）
    @State private var selectedTerritory: Territory?

    /// 是否正在加载
    @State private var isLoading = false

    // MARK: - 计算属性

    /// 总面积（平方米）
    private var totalArea: Double {
        myTerritories.reduce(0) { $0 + $1.area }
    }

    /// 格式化总面积
    private var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - 主视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Color.black.ignoresSafeArea()

                if isLoading {
                    // 加载状态
                    loadingView
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    territoryListView
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadMyTerritories()
            }
            .refreshable {
                await loadMyTerritories()
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(
                    territory: territory,
                    onDelete: {
                        selectedTerritory = nil
                        Task {
                            await loadMyTerritories()
                        }
                    }
                )
            }
        }
    }

    // MARK: - 子视图

    /// 加载中视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.green)
                .scaleEffect(1.5)

            Text("加载中...")
                .foregroundColor(.gray)
                .font(.subheadline)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            Text("还没有领地")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("前往地图 Tab，开始圈地吧！")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
    }

    /// 领地列表视图
    private var territoryListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 统计信息头部
                statsHeaderView
                    .padding(.horizontal)
                    .padding(.top)

                // 领地卡片列表
                LazyVStack(spacing: 12) {
                    ForEach(myTerritories) { territory in
                        TerritoryCardView(territory: territory)
                            .onTapGesture {
                                selectedTerritory = territory
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    /// 统计信息头部
    private var statsHeaderView: some View {
        HStack(spacing: 16) {
            // 领地数量
            StatCard(
                icon: "flag.fill",
                title: "领地数量",
                value: "\(myTerritories.count)",
                color: .green
            )

            // 总面积
            StatCard(
                icon: "map.fill",
                title: "总面积",
                value: formattedTotalArea,
                color: .orange
            )
        }
        .frame(height: 100)
    }

    // MARK: - 数据加载

    /// 加载我的领地
    private func loadMyTerritories() async {
        isLoading = true

        do {
            myTerritories = try await territoryManager.loadMyTerritories()
            print("✅ [领地] 加载我的领地成功，共 \(myTerritories.count) 个")
        } catch {
            print("❌ [领地] 加载失败: \(error)")
            myTerritories = []
        }

        isLoading = false
    }
}

// MARK: - 统计卡片视图

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - 领地卡片视图

struct TerritoryCardView: View {
    let territory: Territory

    var body: some View {
        HStack(spacing: 16) {
            // 左侧图标
            Image(systemName: "flag.fill")
                .font(.title)
                .foregroundColor(.green)
                .frame(width: 50, height: 50)
                .background(Color.green.opacity(0.2))
                .cornerRadius(10)

            // 中间信息
            VStack(alignment: .leading, spacing: 6) {
                Text(territory.displayName)
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    Label(territory.formattedArea, systemImage: "map")
                        .font(.caption)
                        .foregroundColor(.gray)

                    if let pointCount = territory.pointCount {
                        Label("\(pointCount) 点", systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            // 右侧箭头
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - 预览

#Preview {
    TerritoryTabView()
}
