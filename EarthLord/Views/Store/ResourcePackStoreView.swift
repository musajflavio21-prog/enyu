//
//  ResourcePackStoreView.swift
//  EarthLord
//
//  物资包商店页
//  展示四档物资包卡片，支持展开查看完整物品清单
//

import SwiftUI
import StoreKit

/// 物资包商店视图
struct ResourcePackStoreView: View {
    @StateObject private var storeManager = StoreManager.shared
    @State private var expandedPack: StoreProductID?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 说明卡片
                infoCard

                // 物资包列表
                ForEach(ResourcePackCatalog.allPacks, id: \.productId) { pack in
                    packCard(pack)
                }
            }
            .padding()
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
    }

    // MARK: - 说明卡片

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("物资包")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text("直接获取生存和建造所需物资，购买后物品将添加到背包中")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 物资包卡片

    private func packCard(_ pack: ResourcePackDefinition) -> some View {
        let product = storeManager.resourcePacks.first { $0.id == pack.productId.rawValue }
        let isExpanded = expandedPack == pack.productId

        return VStack(spacing: 0) {
            // 主卡片
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedPack = isExpanded ? nil : pack.productId
                }
            }) {
                VStack(spacing: 12) {
                    // 顶行：图标 + 名称 + 标签
                    HStack(spacing: 12) {
                        // 品质图标
                        Image(systemName: pack.productId.iconName)
                            .font(.title2)
                            .foregroundColor(pack.themeColor)
                            .frame(width: 40, height: 40)
                            .background(pack.themeColor.opacity(0.15))
                            .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(pack.name)
                                    .font(.headline)
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                if let tag = pack.tag {
                                    Text(tag)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(tagColor(tag))
                                        .cornerRadius(4)
                                }
                            }

                            Text(pack.subtitle)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        Spacer()

                        // 展开箭头
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    // 物品预览（前4个）
                    HStack(spacing: 8) {
                        ForEach(Array(pack.items.prefix(4).enumerated()), id: \.offset) { _, item in
                            itemPreviewChip(item)
                        }

                        if pack.items.count > 4 {
                            Text("+\(pack.items.count - 4)")
                                .font(.caption2)
                                .foregroundColor(ApocalypseTheme.textMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(6)
                        }

                        Spacer()
                    }

                    // 底行：赠送 + 总数 + 价格
                    HStack {
                        // 赠送末日币
                        if pack.bonusCoins > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "bitcoinsign.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(ApocalypseTheme.warning)
                                Text("+\(pack.bonusCoins)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(ApocalypseTheme.warning)
                            }
                        }

                        Text("\(pack.totalItemCount)件物品")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Spacer()

                        // 购买按钮
                        if let product = product {
                            Button(action: {
                                Task { await storeManager.purchase(product) }
                            }) {
                                Text(product.displayPrice)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(pack.themeColor)
                                    .cornerRadius(8)
                            }
                            .disabled(storeManager.isPurchasing)
                        } else {
                            Text(pack.productId.fallbackPrice)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(pack.themeColor.opacity(0.6))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)

            // 展开的完整物品清单
            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.1))

                VStack(spacing: 8) {
                    ForEach(Array(pack.items.enumerated()), id: \.offset) { _, item in
                        itemDetailRow(item)
                    }

                    if pack.bonusCoins > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.warning)
                                .frame(width: 28)

                            Text("末日币")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Spacer()

                            Text("+\(pack.bonusCoins)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(ApocalypseTheme.warning)
                        }
                    }
                }
                .padding()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(pack.themeColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 物品预览标签

    private func itemPreviewChip(_ item: ResourcePackItem) -> some View {
        HStack(spacing: 4) {
            Image(systemName: item.icon)
                .font(.caption2)
                .foregroundColor(rarityColor(item.rarity))
            Text("×\(item.quantity)")
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(rarityColor(item.rarity).opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - 物品详情行

    private func itemDetailRow(_ item: ResourcePackItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.body)
                .foregroundColor(rarityColor(item.rarity))
                .frame(width: 28)

            Text(item.name)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(rarityDisplayName(item.rarity))
                .font(.caption2)
                .foregroundColor(rarityColor(item.rarity))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(rarityColor(item.rarity).opacity(0.1))
                .cornerRadius(3)

            Spacer()

            Text("×\(item.quantity)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - 工具方法

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity {
        case "common": return Color(white: 0.7)
        case "uncommon": return Color(red: 0.2, green: 0.8, blue: 0.4)
        case "rare": return Color(red: 0.3, green: 0.7, blue: 1.0)
        case "epic": return Color(red: 0.7, green: 0.4, blue: 1.0)
        case "legendary": return Color(red: 1.0, green: 0.6, blue: 0.1)
        default: return Color(white: 0.5)
        }
    }

    private func rarityDisplayName(_ rarity: String) -> String {
        switch rarity {
        case "common": return "普通"
        case "uncommon": return "优良"
        case "rare": return "稀有"
        case "epic": return "史诗"
        case "legendary": return "传说"
        default: return rarity
        }
    }

    private func tagColor(_ tag: String) -> Color {
        switch tag {
        case "热门": return ApocalypseTheme.primary
        case "超值": return ApocalypseTheme.info
        case "最划算": return Color(red: 1.0, green: 0.6, blue: 0.1)
        default: return ApocalypseTheme.success
        }
    }
}

#Preview {
    ResourcePackStoreView()
}
