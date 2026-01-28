//
//  BuildingCard.swift
//  EarthLord
//
//  建筑卡片组件
//  用于建筑浏览器中显示建筑模板信息
//

import SwiftUI

/// 建筑卡片视图
struct BuildingCard: View {

    // MARK: - 属性

    /// 建筑模板
    let template: BuildingTemplate

    /// 是否可建造（资源足够且未达上限）
    var canBuild: Bool = true

    /// 当前建造数量
    var currentCount: Int = 0

    /// 点击回调
    var onTap: (() -> Void)?

    // MARK: - 视图

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                // 顶部：图标和等级
                HStack {
                    // 建筑图标
                    Image(systemName: template.iconName)
                        .font(.title)
                        .foregroundColor(canBuild ? .green : .gray)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(canBuild ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        )

                    Spacer()

                    // 层级标识
                    Text("T\(template.tier)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tierColor.opacity(0.8))
                        .cornerRadius(6)
                }

                // 建筑名称
                Text(template.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                // 建筑描述
                Text(template.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .topLeading)

                Divider()
                    .background(Color.gray.opacity(0.3))

                // 底部信息
                HStack {
                    // 建造时间
                    Label(template.formattedBuildTime, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    // 数量限制
                    Text("\(currentCount)/\(template.maxPerTerritory)")
                        .font(.caption)
                        .foregroundColor(currentCount >= template.maxPerTerritory ? .red : .gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(canBuild ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .opacity(canBuild ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 辅助属性

    /// 层级颜色
    private var tierColor: Color {
        switch template.tier {
        case 1: return .gray
        case 2: return .green
        case 3: return .blue
        case 4: return .purple
        case 5: return .orange
        default: return .gray
        }
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            BuildingCard(
                template: BuildingTemplate(
                    id: "campfire",
                    name: "篝火",
                    description: "基础生存设施，提供温暖和烹饪功能。",
                    category: .survival,
                    tier: 1,
                    maxLevel: 3,
                    buildTimeSeconds: 30,
                    requiredResources: ["wood": 30, "stone": 20],
                    maxPerTerritory: 2,
                    iconName: "flame.fill",
                    effect: nil
                ),
                canBuild: true,
                currentCount: 0
            )

            BuildingCard(
                template: BuildingTemplate(
                    id: "shelter",
                    name: "庇护所",
                    description: "简易住所，可以抵御恶劣天气。",
                    category: .survival,
                    tier: 1,
                    maxLevel: 5,
                    buildTimeSeconds: 60,
                    requiredResources: ["wood": 50, "stone": 30],
                    maxPerTerritory: 1,
                    iconName: "house.fill",
                    effect: nil
                ),
                canBuild: false,
                currentCount: 1
            )
        }
        .padding()
    }
    .background(Color.black)
}
