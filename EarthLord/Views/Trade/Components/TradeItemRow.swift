//
//  TradeItemRow.swift
//  EarthLord
//
//  交易物品行组件
//  用于显示交易中的物品信息
//

import SwiftUI

/// 交易物品行
struct TradeItemRow: View {
    let itemId: String
    let quantity: Int
    let definitions: [DBItemDefinition]
    var showQuantityEditor: Bool = false
    var maxQuantity: Int? = nil
    var onQuantityChange: ((Int) -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    /// 物品定义
    private var definition: DBItemDefinition? {
        definitions.first { $0.id == itemId }
    }

    /// 分类图标
    private var categoryIcon: String {
        guard let category = definition?.category else { return "questionmark.circle" }
        switch category {
        case "water": return "drop.fill"
        case "food": return "fork.knife"
        case "medical": return "cross.case.fill"
        case "material": return "cube.fill"
        case "tool": return "wrench.and.screwdriver.fill"
        default: return "questionmark.circle"
        }
    }

    /// 分类颜色
    private var categoryColor: Color {
        guard let category = definition?.category else { return .gray }
        switch category {
        case "water": return .cyan
        case "food": return .orange
        case "medical": return .red
        case "material": return .brown
        case "tool": return .gray
        default: return .secondary
        }
    }

    /// 稀有度颜色
    private var rarityColor: Color {
        guard let rarity = definition?.rarity else { return .gray }
        switch rarity {
        case "common": return .gray
        case "uncommon": return .green
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: definition?.icon ?? categoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(definition?.name ?? "未知物品")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 6) {
                    // 稀有度标签
                    Text(rarityDisplayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(rarityColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rarityColor.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            Spacer()

            // 数量显示/编辑
            if showQuantityEditor {
                quantityEditor
            } else {
                Text("x\(quantity)")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 删除按钮
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(ApocalypseTheme.background)
        .cornerRadius(10)
    }

    /// 数量编辑器
    private var quantityEditor: some View {
        HStack(spacing: 12) {
            // 减少按钮
            Button(action: {
                if quantity > 1 {
                    onQuantityChange?(quantity - 1)
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(quantity > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            }
            .disabled(quantity <= 1)

            // 数量显示
            Text("\(quantity)")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(minWidth: 30)

            // 增加按钮
            Button(action: {
                if let max = maxQuantity, quantity < max {
                    onQuantityChange?(quantity + 1)
                } else if maxQuantity == nil {
                    onQuantityChange?(quantity + 1)
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(canIncrease ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            }
            .disabled(!canIncrease)
        }
    }

    private var canIncrease: Bool {
        if let max = maxQuantity {
            return quantity < max
        }
        return true
    }

    /// 稀有度显示名称
    private var rarityDisplayName: String {
        guard let rarity = definition?.rarity else { return "普通" }
        switch rarity {
        case "common": return "普通"
        case "uncommon": return "优良"
        case "rare": return "稀有"
        case "epic": return "史诗"
        case "legendary": return "传说"
        default: return rarity
        }
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 12) {
        TradeItemRow(
            itemId: "wood",
            quantity: 10,
            definitions: []
        )

        TradeItemRow(
            itemId: "wood",
            quantity: 5,
            definitions: [],
            showQuantityEditor: true,
            maxQuantity: 20,
            onQuantityChange: { _ in },
            onRemove: { }
        )
    }
    .padding()
    .background(ApocalypseTheme.cardBackground)
}
