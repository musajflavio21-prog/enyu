//
//  TradeMainView.swift
//  EarthLord
//
//  交易系统主入口页面
//  包含我的挂单、交易市场、交易历史三个分段
//

import SwiftUI

/// 交易分段类型
enum TradeSegment: Int, CaseIterable {
    case myOffers = 0
    case market
    case history

    var title: String {
        switch self {
        case .myOffers: return "我的挂单"
        case .market: return "交易市场"
        case .history: return "交易历史"
        }
    }

    var icon: String {
        switch self {
        case .myOffers: return "tag"
        case .market: return "storefront"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

/// 交易系统主视图
struct TradeMainView: View {

    /// 当前选中的分段
    @State private var selectedSegment: TradeSegment = .market

    var body: some View {
        NavigationStack {
            ZStack {
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
        }
    }

    // MARK: - 分段选择器

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(TradeSegment.allCases, id: \.self) { segment in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSegment = segment
                    }
                }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: segment.icon)
                                .font(.system(size: 12))
                            Text(segment.title)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(selectedSegment == segment
                            ? ApocalypseTheme.primary
                            : ApocalypseTheme.textSecondary)

                        // 下划线
                        Rectangle()
                            .fill(selectedSegment == segment
                                ? ApocalypseTheme.primary
                                : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .myOffers:
            MyTradeOffersView()

        case .market:
            TradeMarketView()

        case .history:
            TradeHistoryView()
        }
    }
}

// MARK: - 预览

#Preview {
    TradeMainView()
}
