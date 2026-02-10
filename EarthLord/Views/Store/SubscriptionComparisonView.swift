//
//  SubscriptionComparisonView.swift
//  EarthLord
//
//  VIP订阅对比表
//

import SwiftUI
import StoreKit

/// VIP对比视图
struct SubscriptionComparisonView: View {
    @StateObject private var storeManager = StoreManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 当前状态
                currentStatusCard

                // 对比表
                comparisonTable

                // 购买按钮区域
                purchaseButtons
            }
            .padding()
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .navigationTitle("VIP会员")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 当前状态

    private var currentStatusCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("当前等级")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 8) {
                    Text(storeManager.currentVIPTier.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    VIPBadgeLargeView(tier: storeManager.currentVIPTier)
                }

                if storeManager.isVIPActive,
                   let expires = storeManager.entitlements.vipExpiresAt {
                    Text("到期: \(expires, style: .date)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()

            Image(systemName: storeManager.currentVIPTier.iconName)
                .font(.system(size: 40))
                .foregroundColor(tierColor(storeManager.currentVIPTier))
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 对比表

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            // 表头
            HStack {
                Text("权益")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("免费")
                    .frame(width: 60)
                Text("幸存者")
                    .frame(width: 60)
                Text("领主")
                    .frame(width: 60)
            }
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(ApocalypseTheme.textSecondary)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(ApocalypseTheme.cardBackground)

            Divider().background(Color.gray.opacity(0.3))

            comparisonRow("领地数量", free: "3块", survivor: "10块", lord: "无限")
            comparisonRow("背包容量", free: "30kg", survivor: "50kg", lord: "100kg")
            comparisonRow("高级通讯", free: "---", survivor: "营地电台", lord: "军用通讯")
            comparisonRow("每日奖励", free: "---", survivor: "有", lord: "有")
            comparisonRow("AI物品", free: "---", survivor: "---", lord: "2次/天")
            comparisonRow("建造速度", free: "1x", survivor: "1x", lord: "2x")
            comparisonRow("专属徽章", free: "---", survivor: "VIP", lord: "LORD")
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func comparisonRow(_ label: String, free: String, survivor: String, lord: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(free)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 60)

            Text(survivor)
                .font(.caption)
                .foregroundColor(.green)
                .frame(width: 60)

            Text(lord)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.warning)
                .frame(width: 60)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.background)
    }

    // MARK: - 购买按钮

    private var purchaseButtons: some View {
        VStack(spacing: 16) {
            // 幸存者VIP
            VStack(spacing: 10) {
                Text("幸存者VIP")
                    .font(.headline)
                    .foregroundColor(.green)

                HStack(spacing: 12) {
                    subscriptionButton(for: .survivorMonthly)
                    subscriptionButton(for: .survivorYearly)
                }
            }

            // 领主VIP
            VStack(spacing: 10) {
                HStack {
                    Text("领主VIP")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.warning)

                    Text("推荐")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(4)
                }

                HStack(spacing: 12) {
                    subscriptionButton(for: .lordMonthly)
                    subscriptionButton(for: .lordYearly)
                }
            }

            // 恢复购买
            Button(action: {
                Task { await storeManager.restorePurchases() }
            }) {
                Text("恢复购买")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.top, 8)
        }
    }

    private func subscriptionButton(for productId: StoreProductID) -> some View {
        let product = storeManager.subscriptions.first { $0.id == productId.rawValue }

        return Button(action: {
            if let product = product {
                Task { await storeManager.purchase(product) }
            }
        }) {
            VStack(spacing: 4) {
                Text(productId.rawValue.contains("monthly") ? "月卡" : "年卡")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(product?.displayPrice ?? productId.fallbackPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if productId.rawValue.contains("yearly") {
                    Text("省30%+")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        productId.rawValue.contains("yearly")
                            ? ApocalypseTheme.primary
                            : Color.gray.opacity(0.3),
                        lineWidth: productId.rawValue.contains("yearly") ? 2 : 1
                    )
            )
        }
        .disabled(storeManager.isPurchasing)
    }

    private func tierColor(_ tier: VIPTier) -> Color {
        switch tier {
        case .none: return .gray
        case .survivor: return .green
        case .lord: return ApocalypseTheme.warning
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionComparisonView()
    }
}
