//
//  TradeMarketView.swift
//  EarthLord
//
//  交易市场页面
//  浏览和接受其他用户的挂单
//

import SwiftUI

/// 交易市场视图
struct TradeMarketView: View {

    @StateObject private var tradeManager = TradeManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 选中查看的挂单
    @State private var selectedOffer: TradeOffer?

    /// 是否显示详情
    @State private var showDetail = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            if tradeManager.availableOffers.isEmpty && !tradeManager.isLoading {
                emptyStateView
            } else {
                offersList
            }

            // 加载中
            if tradeManager.isLoading {
                loadingOverlay
            }
        }
        .task {
            await tradeManager.loadAvailableOffers()
        }
        .refreshable {
            await tradeManager.loadAvailableOffers()
        }
        .navigationDestination(isPresented: $showDetail) {
            if let offer = selectedOffer {
                TradeOfferDetailView(offer: offer)
            }
        }
    }

    // MARK: - 挂单列表

    private var offersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tradeManager.availableOffers) { offer in
                    TradeOfferCard(
                        offer: offer,
                        definitions: inventoryManager.itemDefinitions,
                        isMyOffer: false,
                        onTap: {
                            selectedOffer = offer
                            showDetail = true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "storefront")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无可用的交易挂单")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("其他玩家发布的挂单将显示在这里")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)

            // 刷新按钮
            Button(action: {
                Task {
                    await tradeManager.loadAvailableOffers()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.primary.opacity(0.1))
                .cornerRadius(20)
            }
            .padding(.top, 10)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 加载中

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(ApocalypseTheme.primary)

                Text("加载中...")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(30)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        TradeMarketView()
    }
}
