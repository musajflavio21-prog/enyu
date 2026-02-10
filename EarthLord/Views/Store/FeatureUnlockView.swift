//
//  FeatureUnlockView.swift
//  EarthLord
//
//  功能解锁列表
//

import SwiftUI
import StoreKit

/// 功能解锁视图
struct FeatureUnlockView: View {
    @StateObject private var storeManager = StoreManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("永久解锁")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("一次购买，永久有效")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if storeManager.nonConsumables.isEmpty {
                    ForEach(StoreProductID.nonConsumables, id: \.self) { productId in
                        featureFallbackCard(productId)
                    }
                } else {
                    ForEach(storeManager.nonConsumables, id: \.id) { product in
                        featureCard(product)
                    }
                }
            }
            .padding()
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .navigationTitle("功能解锁")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 功能卡片

    private func featureCard(_ product: Product) -> some View {
        let productId = StoreProductID(rawValue: product.id)
        let isOwned = checkOwnership(productId)

        return HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(isOwned ? ApocalypseTheme.success.opacity(0.2) : ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: productId?.iconName ?? "questionmark")
                    .font(.title2)
                    .foregroundColor(isOwned ? ApocalypseTheme.success : ApocalypseTheme.primary)
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(productId?.displayName ?? product.displayName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(productId?.description ?? "")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // 购买/已拥有
            if isOwned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.success)
            } else {
                Button(action: {
                    Task { await storeManager.purchase(product) }
                }) {
                    Text(product.displayPrice)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(20)
                }
                .disabled(storeManager.isPurchasing)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 备用卡片（StoreKit 未加载时）

    private func featureFallbackCard(_ productId: StoreProductID) -> some View {
        let isOwned = checkOwnership(productId)

        return HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(isOwned ? ApocalypseTheme.success.opacity(0.2) : ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: productId.iconName)
                    .font(.title2)
                    .foregroundColor(isOwned ? ApocalypseTheme.success : ApocalypseTheme.primary)
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(productId.displayName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(productId.description)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // 购买/已拥有
            if isOwned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.success)
            } else {
                Text(productId.fallbackPrice)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ApocalypseTheme.primary.opacity(0.6))
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 检查是否已拥有该功能
    private func checkOwnership(_ productId: StoreProductID?) -> Bool {
        guard let productId = productId else { return false }
        let e = storeManager.entitlements
        switch productId {
        case .unlockSatellite: return e.hasSatelliteDevice
        case .unlockTerritory5: return e.extraTerritorySlots >= 5
        case .unlockRadar: return e.hasPremiumRadar
        case .unlockBackpack: return e.extraBackpackKg >= 30
        default: return false
        }
    }
}

#Preview {
    NavigationStack {
        FeatureUnlockView()
    }
}
