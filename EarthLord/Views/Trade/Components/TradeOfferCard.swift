//
//  TradeOfferCard.swift
//  EarthLord
//
//  交易挂单卡片组件
//  用于在列表中显示挂单信息
//

import SwiftUI

/// 交易挂单卡片
struct TradeOfferCard: View {
    let offer: TradeOffer
    let definitions: [DBItemDefinition]
    var isMyOffer: Bool = false
    var onTap: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                // 顶部：状态 + 时间
                headerRow

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 物品交换信息
                exchangeInfo

                // 留言（如果有）
                if let message = offer.message, !message.isEmpty {
                    Text("\"\(message)\"")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .italic()
                        .lineLimit(2)
                }

                // 底部：用户信息或操作按钮
                bottomRow
            }
            .padding(14)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(statusBorderColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 顶部行

    private var headerRow: some View {
        HStack {
            // 状态标签
            statusBadge

            Spacer()

            // 剩余时间
            if offer.status == .active {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(offer.formattedRemainingTime)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(timeColor)
            } else if let completedAt = offer.completedAt {
                Text(formatDate(completedAt))
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }

    /// 状态标签
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(offer.status.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(statusColor.opacity(0.15))
        .cornerRadius(12)
    }

    // MARK: - 物品交换信息

    private var exchangeInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 提供的物品
            VStack(alignment: .leading, spacing: 6) {
                Text(isMyOffer ? "我出" : "他出")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)

                itemsRow(items: offer.offeringItems)
            }

            // 箭头
            HStack {
                Spacer()
                Image(systemName: "arrow.down")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
                Spacer()
            }

            // 想要的物品
            VStack(alignment: .leading, spacing: 6) {
                Text(isMyOffer ? "我要" : "他要")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)

                itemsRow(items: offer.requestingItems)
            }
        }
    }

    /// 物品行
    private func itemsRow(items: [TradeItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.itemId) { item in
                    itemChip(item: item)
                }
            }
        }
    }

    /// 物品标签
    private func itemChip(item: TradeItem) -> some View {
        let def = definitions.first { $0.id == item.itemId }
        let icon = def?.icon ?? categoryIcon(for: def?.category)
        let color = categoryColor(for: def?.category)

        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            Text(def?.name ?? item.itemId)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("x\(item.quantity)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(ApocalypseTheme.background)
        .cornerRadius(8)
    }

    // MARK: - 底部行

    private var bottomRow: some View {
        HStack {
            // 用户信息
            if isMyOffer {
                if offer.status == .completed, let username = offer.completedByUsername {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                        Text("被 @\(username) 接受")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(ApocalypseTheme.success)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                    Text("@\(offer.ownerUsername ?? "匿名")")
                        .font(.system(size: 13))
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 取消按钮（仅自己的 active 挂单）
            if isMyOffer && offer.status == .active, let onCancel = onCancel {
                Button(action: onCancel) {
                    Text("取消挂单")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.danger)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ApocalypseTheme.danger.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            // 查看详情（他人挂单）
            if !isMyOffer && offer.status == .active {
                Text("查看详情")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.primary.opacity(0.15))
                    .cornerRadius(6)
            }
        }
    }

    // MARK: - 辅助方法

    private var statusColor: Color {
        switch offer.status {
        case .active: return ApocalypseTheme.info
        case .completed: return ApocalypseTheme.success
        case .cancelled: return ApocalypseTheme.textMuted
        case .expired: return ApocalypseTheme.warning
        }
    }

    private var statusBorderColor: Color {
        switch offer.status {
        case .active: return ApocalypseTheme.info
        case .completed: return ApocalypseTheme.success
        case .cancelled: return ApocalypseTheme.textMuted
        case .expired: return ApocalypseTheme.warning
        }
    }

    private var timeColor: Color {
        let remaining = offer.remainingTimeSeconds
        if remaining < 3600 { // 少于1小时
            return ApocalypseTheme.danger
        } else if remaining < 6 * 3600 { // 少于6小时
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.textSecondary
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
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
    VStack(spacing: 16) {
        Text("挂单卡片预览")
            .font(.headline)
            .foregroundColor(.white)
    }
    .padding()
    .background(ApocalypseTheme.background)
}
