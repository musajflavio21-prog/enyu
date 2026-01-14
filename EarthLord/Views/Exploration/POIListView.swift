//
//  POIListView.swift
//  EarthLord
//
//  附近兴趣点列表页面
//  显示可探索的POI（Point of Interest）列表
//

import SwiftUI

struct POIListView: View {

    // MARK: - 状态属性

    /// POI 列表数据
    @State private var poiList: [POI] = MockPOIData.poiList

    /// 当前选中的筛选分类（nil 表示全部）
    @State private var selectedCategory: POIType? = nil

    /// 是否正在搜索
    @State private var isSearching = false

    /// 搜索按钮缩放状态
    @State private var isSearchButtonPressed = false

    /// 列表项显示状态（用于淡入动画）
    @State private var visibleItems: Set<String> = []

    /// 假的 GPS 坐标
    private let mockLatitude = 22.54
    private let mockLongitude = 114.06

    // MARK: - 计算属性

    /// 筛选后的 POI 列表
    private var filteredPOIs: [POI] {
        if let category = selectedCategory {
            return poiList.filter { $0.type == category }
        }
        return poiList
    }

    /// 已发现的 POI 数量
    private var discoveredCount: Int {
        return poiList.filter { $0.status != .undiscovered }.count
    }

    // MARK: - 主视图

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 筛选工具栏
                filterToolbar
                    .padding(.top, 16)

                // POI 列表
                poiListView
                    .padding(.top, 12)
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态栏

    /// 顶部状态栏：显示 GPS 坐标和发现数量
    private var statusBar: some View {
        HStack {
            // GPS 坐标
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(String(format: "%.2f, %.2f", mockLatitude, mockLongitude))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 发现数量
            Text("附近发现 \(discoveredCount) 个地点")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    // MARK: - 搜索按钮

    /// 搜索附近 POI 的按钮
    private var searchButton: some View {
        Button(action: {
            performSearch()
        }) {
            HStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("搜索附近POI")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSearching ? ApocalypseTheme.textSecondary : ApocalypseTheme.primary)
            )
        }
        .scaleEffect(isSearchButtonPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSearchButtonPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isSearchButtonPressed = true }
                .onEnded { _ in isSearchButtonPressed = false }
        )
        .disabled(isSearching)
    }

    // MARK: - 筛选工具栏

    /// 横向滚动的分类筛选按钮
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部按钮
                FilterButton(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                // 各分类按钮
                FilterButton(
                    title: "医院",
                    icon: "cross.case.fill",
                    color: .red,
                    isSelected: selectedCategory == .hospital
                ) {
                    selectedCategory = .hospital
                }

                FilterButton(
                    title: "超市",
                    icon: "cart.fill",
                    color: .green,
                    isSelected: selectedCategory == .supermarket
                ) {
                    selectedCategory = .supermarket
                }

                FilterButton(
                    title: "工厂",
                    icon: "building.2.fill",
                    color: .gray,
                    isSelected: selectedCategory == .factory
                ) {
                    selectedCategory = .factory
                }

                FilterButton(
                    title: "药店",
                    icon: "pills.fill",
                    color: .purple,
                    isSelected: selectedCategory == .pharmacy
                ) {
                    selectedCategory = .pharmacy
                }

                FilterButton(
                    title: "加油站",
                    icon: "fuelpump.fill",
                    color: .orange,
                    isSelected: selectedCategory == .gasStation
                ) {
                    selectedCategory = .gasStation
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - POI 列表

    /// POI 列表视图
    private var poiListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredPOIs.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                        let delayTime = 0.1 * Double(index)
                        NavigationLink(destination: POIDetailView(poi: poi)) {
                            POICardContent(poi: poi)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(visibleItems.contains(poi.id) ? 1 : 0)
                        .offset(y: visibleItems.contains(poi.id) ? 0 : 20)
                        .onAppear {
                            // 错开 0.1 秒依次淡入
                            withAnimation(Animation.easeOut(duration: 0.3).delay(delayTime)) {
                                _ = visibleItems.insert(poi.id)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .onChange(of: selectedCategory) { _, _ in
            // 切换分类时重置动画
            visibleItems.removeAll()
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            // 根据情况显示不同的空状态
            if poiList.isEmpty {
                // 没有任何 POI
                Image(systemName: "map")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("附近暂无兴趣点")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("点击搜索按钮发现周围的废墟")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                // 筛选后没有结果
                Image(systemName: "mappin.slash")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("没有找到该类型的地点")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("尝试选择其他分类")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - 方法

    /// 执行搜索（模拟网络请求）
    private func performSearch() {
        isSearching = true

        // 模拟 1.5 秒网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            // 这里可以刷新 POI 数据
            print("🔍 [POI] 搜索完成，发现 \(poiList.count) 个地点")
        }
    }
}

// MARK: - 筛选按钮组件

/// 分类筛选按钮
struct FilterButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color : ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - POI 卡片内容组件

/// POI 卡片内容视图（用于 NavigationLink）
struct POICardContent: View {
    let poi: POI

    /// 根据 POI 类型获取颜色
    private var typeColor: Color {
        switch poi.type {
        case .hospital:
            return .red
        case .supermarket:
            return .green
        case .factory:
            return .gray
        case .pharmacy:
            return .purple
        case .gasStation:
            return .orange
        case .warehouse:
            return .brown
        case .residence:
            return .blue
        }
    }

    /// 根据 POI 类型获取图标
    private var typeIcon: String {
        switch poi.type {
        case .hospital:
            return "cross.case.fill"
        case .supermarket:
            return "cart.fill"
        case .factory:
            return "building.2.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .warehouse:
            return "shippingbox.fill"
        case .residence:
            return "house.fill"
        }
    }

    /// 发现状态文本
    private var statusText: String {
        switch poi.status {
        case .undiscovered:
            return "未发现"
        case .discovered:
            return "已发现"
        case .looted:
            return "已搜空"
        }
    }

    /// 发现状态颜色
    private var statusColor: Color {
        switch poi.status {
        case .undiscovered:
            return ApocalypseTheme.textMuted
        case .discovered:
            return ApocalypseTheme.success
        case .looted:
            return ApocalypseTheme.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // 左侧：类型图标
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: typeIcon)
                    .font(.system(size: 22))
                    .foregroundColor(typeColor)
            }

            // 中间：名称和信息
            VStack(alignment: .leading, spacing: 6) {
                // 名称
                Text(poi.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 类型和状态
                HStack(spacing: 12) {
                    // 类型标签
                    HStack(spacing: 4) {
                        Image(systemName: typeIcon)
                            .font(.system(size: 10))
                        Text(poi.type.displayName)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(typeColor)

                    // 发现状态
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(statusColor)
                }
            }

            Spacer()

            // 右侧：物资状态和箭头
            VStack(alignment: .trailing, spacing: 6) {
                // 物资状态
                if poi.status == .discovered && poi.hasLoot {
                    HStack(spacing: 4) {
                        Image(systemName: "cube.box.fill")
                            .font(.system(size: 10))
                        Text("有物资")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.warning.opacity(0.15))
                    .cornerRadius(6)
                } else if poi.status == .looted {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                        Text("已搜空")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.textMuted.opacity(0.15))
                    .cornerRadius(6)
                } else if poi.status == .undiscovered {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 10))
                        Text("未知")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.textMuted.opacity(0.15))
                    .cornerRadius(6)
                }

                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        POIListView()
    }
}
