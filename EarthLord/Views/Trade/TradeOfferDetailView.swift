//
//  TradeOfferDetailView.swift
//  EarthLord
//
//  挂单详情页面
//  查看挂单详情并接受交易
//

import SwiftUI

/// 挂单详情视图
struct TradeOfferDetailView: View {

    let offer: TradeOffer

    @Environment(\.dismiss) private var dismiss

    @StateObject private var tradeManager = TradeManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 是否显示确认弹窗
    @State private var showConfirm = false

    /// 是否正在处理
    @State private var isProcessing = false

    /// 错误信息
    @State private var errorMessage: String?
    @State private var showError = false

    /// 成功信息
    @State private var showSuccess = false

    /// 检查库存是否足够
    private var inventoryCheck: [(item: TradeItem, required: Int, available: Int, isSufficient: Bool)] {
        offer.requestingItems.map { item in
            let available = inventoryManager.getAvailableQuantity(itemId: item.itemId)
            return (item, item.quantity, available, available >= item.quantity)
        }
    }

    /// 是否可以接受交易
    private var canAccept: Bool {
        inventoryCheck.allSatisfy { $0.isSufficient } && !isProcessing
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 发布者信息
                    ownerSection

                    // 交易内容
                    exchangeSection

                    // 留言
                    if let message = offer.message, !message.isEmpty {
                        messageSection(message)
                    }

                    // 库存检查
                    inventoryCheckSection

                    // 接受按钮
                    acceptButton
                }
                .padding(16)
            }

            // 处理中
            if isProcessing {
                loadingOverlay
            }
        }
        .navigationTitle("挂单详情")
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认交易", isPresented: $showConfirm) {
            Button("取消", role: .cancel) { }
            Button("确认交易", role: .none) {
                acceptOffer()
            }
        } message: {
            Text("确认后，物品将立即交换。")
        }
        .alert("错误", isPresented: $showError) {
            Button("确定") { }
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .alert("交易成功", isPresented: $showSuccess) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("物品已交换到你的背包中")
        }
    }

    // MARK: - 发布者信息

    private var ownerSection: some View {
        HStack(spacing: 12) {
            // 头像
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("@\(offer.ownerUsername ?? "匿名")")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 8) {
                    Text("发布于 \(formatTimeAgo(offer.createdAt))")
                    Text("·")
                    Text("剩余 \(offer.formattedRemainingTime)")
                }
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 交易内容

    private var exchangeSection: some View {
        VStack(spacing: 16) {
            // 他提供
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(ApocalypseTheme.success)
                    Text("他提供")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("(你将获得)")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                itemsGrid(items: offer.offeringItems)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 他想要
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(ApocalypseTheme.danger)
                    Text("他想要")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("(你需要付出)")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                itemsGrid(items: offer.requestingItems)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 物品网格
    private func itemsGrid(items: [TradeItem]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            ForEach(items, id: \.itemId) { item in
                itemCard(item: item)
            }
        }
    }

    /// 物品卡片
    private func itemCard(item: TradeItem) -> some View {
        let def = inventoryManager.itemDefinitions.first { $0.id == item.itemId }
        let icon = def?.icon ?? categoryIcon(for: def?.category)
        let color = categoryColor(for: def?.category)

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }

            Text(def?.name ?? item.itemId)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)

            Text("x\(item.quantity)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(ApocalypseTheme.background)
        .cornerRadius(10)
    }

    // MARK: - 留言

    private func messageSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(ApocalypseTheme.info)
                Text("留言")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text("\"\(message)\"")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .italic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 库存检查

    private var inventoryCheckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bag.fill")
                    .foregroundColor(ApocalypseTheme.warning)
                Text("你的库存")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            ForEach(inventoryCheck, id: \.item.itemId) { check in
                HStack {
                    let def = inventoryManager.itemDefinitions.first { $0.id == check.item.itemId }

                    Text(def?.name ?? check.item.itemId)
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text("需要 \(check.required) / 拥有 \(check.available)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(check.isSufficient ? ApocalypseTheme.textSecondary : ApocalypseTheme.danger)

                    Image(systemName: check.isSufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(check.isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 接受按钮

    private var acceptButton: some View {
        Button(action: { showConfirm = true }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("接受交易")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canAccept ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
            .cornerRadius(12)
        }
        .disabled(!canAccept)
        .padding(.top, 10)
    }

    // MARK: - 加载中

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(ApocalypseTheme.primary)

                Text("处理中...")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(30)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - 处理方法

    private func acceptOffer() {
        isProcessing = true

        Task {
            let result = await tradeManager.acceptOffer(offer.id)
            isProcessing = false

            switch result {
            case .success:
                showSuccess = true

            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - 辅助方法

    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3600)
        if hours < 1 {
            let minutes = Int(interval / 60)
            return "\(max(1, minutes))分钟前"
        } else if hours < 24 {
            return "\(hours)小时前"
        } else {
            return "\(hours / 24)天前"
        }
    }

    private func categoryIcon(for category: String?) -> String {
        guard let category = category else { return "questionmark.circle" }
        switch category {
        case "water": return "drop.fill"
        case "food": return "fork.knife"
        case "medical": return "cross.case.fill"
        case "material": return "cube.fill"
        case "tool": return "wrench.and.screwdriver.fill"
        default: return "questionmark.circle"
        }
    }

    private func categoryColor(for category: String?) -> Color {
        guard let category = category else { return .gray }
        switch category {
        case "water": return .cyan
        case "food": return .orange
        case "medical": return .red
        case "material": return .brown
        case "tool": return .gray
        default: return .secondary
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        Text("预览需要真实数据")
    }
}
