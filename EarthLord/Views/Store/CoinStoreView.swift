//
//  CoinStoreView.swift
//  EarthLord
//
//  末日币购买页
//

import SwiftUI
import StoreKit

/// 末日币商店视图
struct CoinStoreView: View {
    @StateObject private var storeManager = StoreManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 当前余额
                balanceCard

                // 末日币说明
                usageInfoCard

                // 购买选项
                VStack(spacing: 12) {
                    Text("充值末日币")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if storeManager.consumables.isEmpty {
                        ForEach(StoreProductID.consumables, id: \.self) { productId in
                            coinFallbackCard(productId)
                        }
                    } else {
                        ForEach(storeManager.consumables, id: \.id) { product in
                            coinProductCard(product)
                        }
                    }
                }
            }
            .padding()
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .navigationTitle("末日币")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 余额卡片

    private var balanceCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("当前余额")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 8) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.title)
                        .foregroundColor(ApocalypseTheme.warning)

                    Text("\(storeManager.coinBalance)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.warning)
                }
            }

            Spacer()
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 用途说明

    private var usageInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("末日币用途")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                usageRow(icon: "bolt.fill", text: "加速建造")
                usageRow(icon: "gift.fill", text: "特殊道具")
                usageRow(icon: "arrow.triangle.2.circlepath", text: "快速交易")
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func usageRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 产品卡片

    private func coinProductCard(_ product: Product) -> some View {
        let productId = StoreProductID(rawValue: product.id)
        let coinAmount = productId?.coinAmount ?? 0

        return Button(action: {
            Task { await storeManager.purchase(product) }
        }) {
            HStack(spacing: 16) {
                // 图标 + 数量
                HStack(spacing: 8) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.warning)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(coinAmount)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("末日币")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                // 标签
                if coinAmount >= 1280 {
                    Text("最划算")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(4)
                } else if coinAmount >= 360 {
                    Text("超值")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.success)
                        .cornerRadius(4)
                }

                // 价格
                Text(product.displayPrice)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.primary)
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(storeManager.isPurchasing)
    }

    // MARK: - 备用卡片（StoreKit 未加载时）

    private func coinFallbackCard(_ productId: StoreProductID) -> some View {
        let coinAmount = productId.coinAmount ?? 0

        return HStack(spacing: 16) {
            // 图标 + 数量
            HStack(spacing: 8) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(coinAmount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("末日币")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // 标签
            if coinAmount >= 1280 {
                Text("最划算")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(4)
            } else if coinAmount >= 360 {
                Text("超值")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ApocalypseTheme.success)
                    .cornerRadius(4)
            }

            // 备用价格
            Text(productId.fallbackPrice)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.primary.opacity(0.6))
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        CoinStoreView()
    }
}
