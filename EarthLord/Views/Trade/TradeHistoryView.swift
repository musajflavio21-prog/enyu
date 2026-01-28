//
//  TradeHistoryView.swift
//  EarthLord
//
//  交易历史页面
//  查看已完成的交易记录，进行评价
//

import SwiftUI

/// 交易历史视图
struct TradeHistoryView: View {

    @StateObject private var tradeManager = TradeManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 当前用户ID
    private var currentUserId: UUID? {
        AuthManager.shared.currentUser?.id
    }

    /// 是否显示评价弹窗
    @State private var showRating = false
    @State private var historyToRate: TradeHistory?

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            if tradeManager.tradeHistory.isEmpty && !tradeManager.isLoading {
                emptyStateView
            } else {
                historyList
            }

            // 加载中
            if tradeManager.isLoading {
                loadingOverlay
            }
        }
        .task {
            await tradeManager.loadTradeHistory()
        }
        .refreshable {
            await tradeManager.loadTradeHistory()
        }
        .sheet(isPresented: $showRating) {
            if let history = historyToRate {
                let partnerName = getPartnerUsername(history)
                RatingSheetView(
                    historyId: history.id,
                    partnerUsername: partnerName,
                    isPresented: $showRating,
                    onSubmit: { rating, comment in
                        submitRating(history: history, rating: rating, comment: comment)
                    }
                )
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - 历史列表

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tradeManager.tradeHistory) { history in
                    historyCard(history)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    /// 历史卡片
    private func historyCard(_ history: TradeHistory) -> some View {
        let isSeller = history.sellerId == currentUserId
        let partnerName = getPartnerUsername(history)
        let myRating = isSeller ? history.sellerRating : history.buyerRating
        let partnerRating = isSeller ? history.buyerRating : history.sellerRating

        return VStack(alignment: .leading, spacing: 12) {
            // 顶部：交易对象和时间
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                    Text("与 @\(partnerName) 的交易")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text(history.formattedCompletedAt)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 交换内容
            VStack(alignment: .leading, spacing: 8) {
                // 我给出的
                HStack(spacing: 6) {
                    Text("你给出:")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    itemsText(items: isSeller ? history.itemsExchanged.offered : history.itemsExchanged.requested)
                }

                // 我获得的
                HStack(spacing: 6) {
                    Text("你获得:")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    itemsText(items: isSeller ? history.itemsExchanged.requested : history.itemsExchanged.offered)
                }
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 评价区域
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // 我的评价
                    HStack(spacing: 6) {
                        Text("你的评价:")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        if let rating = myRating {
                            RatingDisplayView(rating: rating)
                        } else {
                            Text("未评价")
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }

                    // 对方评价
                    HStack(spacing: 6) {
                        Text("对方评价:")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        if let rating = partnerRating {
                            RatingDisplayView(rating: rating)
                        } else {
                            Text("未评价")
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }
                }

                Spacer()

                // 去评价按钮
                if myRating == nil {
                    Button(action: {
                        historyToRate = history
                        showRating = true
                    }) {
                        Text("去评价")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(ApocalypseTheme.primary.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 物品文本
    private func itemsText(items: [TradeItem]) -> some View {
        let text = items.map { item -> String in
            let def = inventoryManager.itemDefinitions.first { $0.id == item.itemId }
            return "\(def?.name ?? item.itemId) x\(item.quantity)"
        }.joined(separator: ", ")

        return Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(ApocalypseTheme.textPrimary)
            .lineLimit(1)
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有交易记录")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("完成交易后，记录将显示在这里")
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

                Text("加载中...")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(30)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - 辅助方法

    private func getPartnerUsername(_ history: TradeHistory) -> String {
        if history.sellerId == currentUserId {
            return history.buyerUsername ?? "匿名"
        } else {
            return history.sellerUsername ?? "匿名"
        }
    }

    private func submitRating(history: TradeHistory, rating: Int, comment: String?) {
        Task {
            let result = await tradeManager.rateTrade(history.id, rating: rating, comment: comment)

            switch result {
            case .success:
                showRating = false
                historyToRate = nil

            case .failure(let error):
                print("评价失败: \(error)")
            }
        }
    }
}

// MARK: - 预览

#Preview {
    TradeHistoryView()
}
