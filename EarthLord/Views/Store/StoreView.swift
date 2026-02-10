//
//  StoreView.swift
//  EarthLord
//
//  商店主页
//  四个Tab：VIP会员 / 末日币 / 物资包 / 功能解锁
//

import SwiftUI

/// 商店主视图
struct StoreView: View {
    @StateObject private var storeManager = StoreManager.shared
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部余额栏
                topBar

                // Tab切换
                tabSelector

                // 内容
                TabView(selection: $selectedTab) {
                    SubscriptionComparisonView()
                        .tag(0)

                    CoinStoreView()
                        .tag(1)

                    ResourcePackStoreView()
                        .tag(2)

                    FeatureUnlockView()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("商店")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .onAppear {
                Task {
                    await storeManager.loadProducts()
                }
            }
            .alert("购买成功", isPresented: .init(
                get: { storeManager.purchaseSuccessMessage != nil },
                set: { if !$0 { storeManager.purchaseSuccessMessage = nil } }
            )) {
                Button("好的") {
                    storeManager.purchaseSuccessMessage = nil
                }
            } message: {
                Text(storeManager.purchaseSuccessMessage ?? "")
            }
            .alert("提示", isPresented: .init(
                get: { storeManager.errorMessage != nil },
                set: { if !$0 { storeManager.errorMessage = nil } }
            )) {
                Button("确定") {
                    storeManager.errorMessage = nil
                }
            } message: {
                Text(storeManager.errorMessage ?? "")
            }
            .overlay {
                if storeManager.isPurchasing {
                    ZStack {
                        Color.black.opacity(0.5)
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("处理中...")
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                        .padding(30)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(16)
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack {
            VIPBadgeLargeView(tier: storeManager.currentVIPTier)

            Spacer()

            CoinBalanceView()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Tab选择器

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton("VIP会员", icon: "crown.fill", index: 0)
            tabButton("末日币", icon: "bitcoinsign.circle.fill", index: 1)
            tabButton("物资包", icon: "shippingbox.fill", index: 2)
            tabButton("功能解锁", icon: "lock.open.fill", index: 3)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    private func tabButton(_ title: String, icon: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .background(
                selectedTab == index
                    ? ApocalypseTheme.primary.opacity(0.1)
                    : Color.clear
            )
            .cornerRadius(8)
        }
    }
}

#Preview {
    StoreView()
}
