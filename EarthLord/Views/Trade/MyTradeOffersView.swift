//
//  MyTradeOffersView.swift
//  EarthLord
//
//  我的挂单页面
//  查看和管理自己发布的所有挂单
//

import SwiftUI

/// 我的挂单视图
struct MyTradeOffersView: View {

    @StateObject private var tradeManager = TradeManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 是否显示发布页面
    @State private var showCreateOffer = false

    /// 是否显示取消确认
    @State private var showCancelConfirm = false
    @State private var offerToCancel: TradeOffer?

    /// 是否正在取消
    @State private var isCancelling = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 发布新挂单按钮
                createOfferButton
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // 挂单列表
                if tradeManager.myOffers.isEmpty && !tradeManager.isLoading {
                    emptyStateView
                } else {
                    offersList
                }
            }

            // 加载中
            if tradeManager.isLoading {
                loadingOverlay
            }
        }
        .task {
            await tradeManager.loadMyOffers()
        }
        .refreshable {
            await tradeManager.loadMyOffers()
        }
        .sheet(isPresented: $showCreateOffer) {
            CreateTradeOfferView()
        }
        .alert("确认取消", isPresented: $showCancelConfirm) {
            Button("取消", role: .cancel) { }
            Button("确认取消挂单", role: .destructive) {
                cancelOffer()
            }
        } message: {
            Text("取消后，已锁定的物品将退回到您的背包。")
        }
    }

    // MARK: - 发布新挂单按钮

    private var createOfferButton: some View {
        Button(action: { showCreateOffer = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text("发布新挂单")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ApocalypseTheme.primary)
            .cornerRadius(12)
        }
    }

    // MARK: - 挂单列表

    private var offersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tradeManager.myOffers) { offer in
                    TradeOfferCard(
                        offer: offer,
                        definitions: inventoryManager.itemDefinitions,
                        isMyOffer: true,
                        onTap: nil,
                        onCancel: {
                            offerToCancel = offer
                            showCancelConfirm = true
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

            Image(systemName: "tag")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有发布过挂单")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("点击上方按钮发布你的第一个交易挂单")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)

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

                Text(isCancelling ? "取消中..." : "加载中...")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(30)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - 取消挂单

    private func cancelOffer() {
        guard let offer = offerToCancel else { return }

        isCancelling = true

        Task {
            let result = await tradeManager.cancelOffer(offer.id)
            isCancelling = false

            switch result {
            case .success:
                offerToCancel = nil

            case .failure(let error):
                print("取消挂单失败: \(error)")
            }
        }
    }
}

// MARK: - 预览

#Preview {
    MyTradeOffersView()
}
