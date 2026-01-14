//
//  POIDetailView.swift
//  EarthLord
//
//  POI详情页面
//  显示兴趣点的详细信息，支持搜寻操作
//

import SwiftUI

struct POIDetailView: View {

    // MARK: - 属性

    /// POI 数据
    let poi: POI

    /// 关闭页面
    @Environment(\.dismiss) private var dismiss

    /// 是否显示探索结果
    @State private var showExplorationResult = false

    /// 是否正在搜寻
    @State private var isSearching = false

    // MARK: - 计算属性

    /// 根据 POI 类型获取主题色
    private var themeColor: Color {
        switch poi.type {
        case .hospital:
            return .red
        case .supermarket:
            return .green
        case .factory:
            return .gray
        case .pharmacy:
            return .purple
        case .gasStation:
            return .orange
        case .warehouse:
            return .brown
        case .residence:
            return .blue
        }
    }

    /// 渐变色
    private var gradientColors: [Color] {
        [themeColor, themeColor.opacity(0.6)]
    }

    /// 类型图标
    private var typeIcon: String {
        poi.type.iconName
    }

    /// 危险等级文本
    private var dangerText: String {
        switch poi.dangerLevel {
        case 1:
            return "安全"
        case 2:
            return "低危"
        case 3:
            return "中危"
        case 4:
            return "高危"
        case 5:
            return "极危"
        default:
            return "未知"
        }
    }

    /// 危险等级颜色
    private var dangerColor: Color {
        switch poi.dangerLevel {
        case 1:
            return .green
        case 2:
            return .cyan
        case 3:
            return .yellow
        case 4:
            return .orange
        case 5:
            return .red
        default:
            return .gray
        }
    }

    /// 是否可以搜寻
    private var canSearch: Bool {
        poi.status != .looted && poi.hasLoot
    }

    // MARK: - 主视图

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部大图区域
                headerSection

                // 内容区域
                ScrollView {
                    VStack(spacing: 16) {
                        // 信息卡片
                        infoCard

                        // 描述卡片
                        descriptionCard

                        // 操作按钮区域
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // 分享功能占位
                    print("📍 [POI] 分享: \(poi.name)")
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showExplorationResult) {
            // 使用 ExplorationResultView 并传递假探索结果
            ExplorationResultView(result: MockExplorationResult.sampleResult)
        }
    }

    // MARK: - 顶部大图区域

    private var headerSection: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 渐变背景
                LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 大图标
                VStack {
                    Spacer()

                    Image(systemName: typeIcon)
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()
                }

                // 底部遮罩和文字
                VStack(spacing: 6) {
                    Spacer()

                    // 名称
                    Text(poi.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    // 类型标签
                    HStack(spacing: 6) {
                        Image(systemName: typeIcon)
                            .font(.system(size: 14))
                        Text(poi.type.displayName)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .black.opacity(0.3),
                            .black.opacity(0.6)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: UIScreen.main.bounds.height / 3)
    }

    // MARK: - 信息卡片

    private var infoCard: some View {
        VStack(spacing: 0) {
            // 距离
            POIInfoRow(
                icon: "location.fill",
                iconColor: ApocalypseTheme.primary,
                title: "距离",
                value: "350米",
                valueColor: ApocalypseTheme.textPrimary
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 物资状态
            POIInfoRow(
                icon: "cube.box.fill",
                iconColor: poi.hasLoot ? ApocalypseTheme.warning : ApocalypseTheme.textMuted,
                title: "物资状态",
                value: poi.status == .looted ? "已清空" : (poi.hasLoot ? "有物资" : "无物资"),
                valueColor: poi.status == .looted ? ApocalypseTheme.textMuted : (poi.hasLoot ? ApocalypseTheme.warning : ApocalypseTheme.textSecondary)
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 危险等级
            POIInfoRow(
                icon: "exclamationmark.triangle.fill",
                iconColor: dangerColor,
                title: "危险等级",
                value: dangerText,
                valueColor: dangerColor
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 来源
            POIInfoRow(
                icon: "map.fill",
                iconColor: .blue,
                title: "来源",
                value: "地图数据",
                valueColor: ApocalypseTheme.textSecondary
            )
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 描述卡片

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("地点描述")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 描述内容
            Text(poi.description)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 操作按钮区域

    private var actionButtons: some View {
        VStack(spacing: 14) {
            // 主按钮：搜寻此POI
            Button(action: {
                performSearch()
            }) {
                HStack(spacing: 12) {
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)

                        Text("搜寻中...")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        Text("搜寻此POI")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Group {
                        if canSearch && !isSearching {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.orange,
                                    Color.orange.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ApocalypseTheme.textMuted,
                                    ApocalypseTheme.textMuted.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .cornerRadius(14)
                .shadow(color: canSearch ? .orange.opacity(0.3) : .clear, radius: 8, y: 4)
            }
            .disabled(!canSearch || isSearching)

            // 已清空提示
            if poi.status == .looted {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13))
                    Text("此地点已被搜空，无法再次搜寻")
                        .font(.system(size: 13))
                }
                .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 两个小按钮
            HStack(spacing: 12) {
                // 标记已发现
                SecondaryButton(
                    title: "标记已发现",
                    icon: "eye.fill",
                    isActive: poi.status == .discovered
                ) {
                    print("📍 [POI] 标记已发现: \(poi.name)")
                }

                // 标记无物资
                SecondaryButton(
                    title: "标记无物资",
                    icon: "xmark.circle.fill",
                    isActive: !poi.hasLoot
                ) {
                    print("📍 [POI] 标记无物资: \(poi.name)")
                }
            }
        }
    }

    // MARK: - 方法

    /// 执行搜寻
    private func performSearch() {
        isSearching = true

        // 模拟搜寻过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSearching = false
            showExplorationResult = true
            print("🔍 [POI] 搜寻完成: \(poi.name)")
        }
    }
}

// MARK: - POI 信息行组件

struct POIInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack {
            // 左侧：图标和标题
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 右侧：值
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - 次要按钮组件

struct SecondaryButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isActive ? .white : ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? .clear : ApocalypseTheme.textMuted.opacity(0.5), lineWidth: 1)
            )
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        POIDetailView(poi: MockPOIData.poiList[0])
    }
}

#Preview("已搜空状态") {
    NavigationStack {
        POIDetailView(poi: MockPOIData.poiList[1])
    }
}
