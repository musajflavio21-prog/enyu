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
                            HStack(spacing: 12) {
                                // 物品图标
                                ZStack {
                                    Circle()
                                        .fill(rarityColor(item.definition?.rarity).opacity(0.2))
                                        .frame(width: 40, height: 40)

                                    Image(systemName: item.definition?.category.iconName ?? "cube.fill")
                                        .foregroundColor(rarityColor(item.definition?.rarity))
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

    private func rarityColor(_ rarity: ItemRarity?) -> Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        case .none: return .gray
        }
    }
}
