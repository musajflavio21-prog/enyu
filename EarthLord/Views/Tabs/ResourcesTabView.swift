//
//  ResourcesTabView.swift
//  EarthLord
//
//  资源模块主入口页面
//  包含 POI、背包、已购、领地、交易 五个分段
//

import SwiftUI

/// 资源分段类型
enum ResourceSegment: Int, CaseIterable {
    case poi = 0
    case backpack
    case purchased
    case territory
    case trade

    var title: String {
        switch self {
        case .poi: return "POI"
        case .backpack: return "背包"
        case .purchased: return "已购"
        case .territory: return "领地"
        case .trade: return "交易"
        }
    }
}

struct ResourcesTabView: View {

    // MARK: - 状态属性

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态
    @State private var isTradeEnabled = false

    // MARK: - 主视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分段选择器
                    segmentPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 交易开关
                    tradeToggle
                }
            }
        }
    }

    // MARK: - 分段选择器

    private var segmentPicker: some View {
        Picker("资源分段", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 交易开关

    private var tradeToggle: some View {
        HStack(spacing: 6) {
            Image(systemName: isTradeEnabled ? "arrow.left.arrow.right.circle.fill" : "arrow.left.arrow.right.circle")
                .font(.system(size: 16))
                .foregroundColor(isTradeEnabled ? ApocalypseTheme.success : ApocalypseTheme.textMuted)

            Toggle("", isOn: $isTradeEnabled)
                .labelsHidden()
                .scaleEffect(0.8)
                .onChange(of: isTradeEnabled) { _, newValue in
                    print("🔄 [资源] 交易开关: \(newValue ? "开启" : "关闭")")
                }
        }
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .poi:
            POIListView()

        case .backpack:
            BackpackView()

        case .purchased:
            PlaceholderContentView(
                icon: "bag.fill",
                title: "已购物品",
                message: "功能开发中"
            )

        case .territory:
            PlaceholderContentView(
                icon: "building.2.fill",
                title: "领地仓库",
                message: "功能开发中"
            )

        case .trade:
            TradeMainView()
        }
    }
}

// MARK: - 占位内容视图

struct PlaceholderContentView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 标题
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 消息
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 预览

#Preview {
    ResourcesTabView()
}
