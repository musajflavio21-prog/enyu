//
//  ScavengeResultView.swift
//  EarthLord
//
//  搜刮结果展示页面
//  显示玩家从 POI 搜刮获得的物品列表
//

import SwiftUI

struct ScavengeResultView: View {
    let poiName: String
    let items: [LootRecord]
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            VStack(spacing: 8) {
                Text("🎉 搜刮成功！")
                    .font(.title)
                    .fontWeight(.bold)

                Text(poiName)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)

            Divider()

            // 物品列表
            VStack(alignment: .leading, spacing: 16) {
                Text("获得物品：")
                    .font(.headline)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 0) {
                                // 物品基本信息卡片
                                HStack(spacing: 12) {
                                    // 物品图标
                                    ZStack {
                                        Circle()
                                            .fill(rarityColor(item).opacity(0.2))
                                            .frame(width: 40, height: 40)

                                        Image(systemName: categoryIcon(item))
                                            .foregroundColor(rarityColor(item))
                                    }

                                    // 物品信息
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.displayName)
                                            .font(.body)
                                            .fontWeight(.medium)

                                        if let quality = item.quality {
                                            Text("品质: \(quality.rawValue)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        // AI生成物品显示稀有度标签
                                        if item.isAIGenerated, let rarity = item.aiRarity {
                                            Text(rarityDisplayName(rarity))
                                                .font(.caption)
                                                .foregroundColor(rarityColor(item))
                                        }
                                    }

                                    Spacer()

                                    // 数量
                                    Text("x\(item.quantity)")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)

                                // AI生成物品的背景故事
                                if item.isAIGenerated, let story = item.aiStory {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Divider()
                                            .padding(.horizontal, 12)

                                        Text(story)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineSpacing(2)
                                            .padding(.horizontal, 12)
                                            .padding(.bottom, 8)
                                    }
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            // 确认按钮
            Button(action: onConfirm) {
                Text("确认")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(24)
        .presentationDetents([.height(500)])
    }

    // MARK: - 辅助方法

    /// 获取稀有度颜色（支持AI和非AI物品）
    private func rarityColor(_ item: LootRecord) -> Color {
        if let aiRarity = item.aiRarity {
            // AI生成物品的稀有度
            switch aiRarity {
            case "common": return .gray
            case "uncommon": return .green
            case "rare": return .blue
            case "epic": return .purple
            case "legendary": return .orange
            default: return .gray
            }
        } else if let rarity = item.definition?.rarity {
            // 非AI物品的稀有度
            switch rarity {
            case .common: return .gray
            case .uncommon: return .green
            case .rare: return .blue
            case .epic: return .purple
            case .legendary: return .orange
            }
        } else {
            return .gray
        }
    }

    /// 获取稀有度中文名称
    private func rarityDisplayName(_ rarity: String) -> String {
        switch rarity {
        case "common": return "普通"
        case "uncommon": return "优秀"
        case "rare": return "稀有"
        case "epic": return "史诗"
        case "legendary": return "传奇"
        default: return rarity
        }
    }

    /// 获取分类图标（支持AI和非AI物品）
    private func categoryIcon(_ item: LootRecord) -> String {
        if let aiCategory = item.aiCategory {
            // AI生成物品的分类
            switch aiCategory {
            case "医疗": return "cross.case.fill"
            case "食物": return "fork.knife"
            case "工具": return "wrench.and.screwdriver.fill"
            case "武器": return "shield.fill"
            case "材料": return "cube.fill"
            default: return "cube.fill"
            }
        } else if let category = item.definition?.category {
            // 非AI物品的分类
            return category.iconName
        } else {
            return "cube.fill"
        }
    }
}
