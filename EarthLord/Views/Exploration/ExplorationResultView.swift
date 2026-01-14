//
//  ExplorationResultView.swift
//  EarthLord
//
//  探索结果页面
//  探索结束后以 Sheet 方式弹出，显示统计数据和获得物品
//

import SwiftUI

struct ExplorationResultView: View {

    // MARK: - 属性

    /// 探索结果数据（新格式，可选）
    let explorationResult: ExplorationResult?

    /// 探索结果数据（旧格式，用于兼容 Mock 数据预览）
    let result: ExplorationStats?

    /// 错误信息（可选）
    var errorMessage: String? = nil

    /// 重试回调
    var onRetry: (() -> Void)? = nil

    /// 关闭页面
    @Environment(\.dismiss) private var dismiss

    /// 动画状态
    @State private var showContent = false
    @State private var showItems = false

    /// 数字动画值
    @State private var animatedDistance: Double = 0
    @State private var animatedDuration: TimeInterval = 0

    /// 物品可见状态
    @State private var visibleLootItems: Set<String> = []

    /// 是否探索失败
    private var isFailed: Bool {
        explorationResult == nil && result == nil
    }

    /// 是否使用新格式数据
    private var useNewFormat: Bool {
        explorationResult != nil
    }

    // MARK: - 初始化器

    /// 新格式初始化（从 ExplorationManager 获取的数据）
    init(explorationResult: ExplorationResult) {
        self.explorationResult = explorationResult
        self.result = nil
        self.errorMessage = nil
        self.onRetry = nil
    }

    /// 旧格式初始化（兼容 Mock 数据）
    init(result: ExplorationStats?, errorMessage: String? = nil, onRetry: (() -> Void)? = nil) {
        self.explorationResult = nil
        self.result = result
        self.errorMessage = errorMessage
        self.onRetry = onRetry
    }

    // MARK: - 主视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isFailed {
                    // 失败状态
                    failedStateView
                } else if useNewFormat, let expResult = explorationResult {
                    // 新格式成功状态
                    ScrollView {
                        VStack(spacing: 24) {
                            // 成就标题（带等级）
                            newAchievementHeader(tier: expResult.tier)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : -20)

                            // 简化统计数据卡片
                            newStatsCard(expResult: expResult)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)

                            // 奖励物品卡片
                            if !expResult.rewards.isEmpty {
                                newRewardsCard(expResult: expResult)
                                    .opacity(showItems ? 1 : 0)
                                    .offset(y: showItems ? 0 : 20)
                            }

                            // 确认按钮
                            confirmButton
                                .opacity(showItems ? 1 : 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                } else if let result = result {
                    // 旧格式成功状态（兼容预览）
                    ScrollView {
                        VStack(spacing: 24) {
                            // 成就标题
                            achievementHeader
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : -20)

                            // 统计数据卡片
                            statsCard
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)

                            // 奖励物品卡片
                            if !result.sessionLoot.isEmpty {
                                rewardsCard
                                    .opacity(showItems ? 1 : 0)
                                    .offset(y: showItems ? 0 : 20)
                            }

                            // 确认按钮
                            confirmButton
                                .opacity(showItems ? 1 : 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(isFailed ? "探索失败" : "探索结果")
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
                guard !isFailed else { return }

                // 动画入场
                withAnimation(.easeOut(duration: 0.5)) {
                    showContent = true
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                    showItems = true
                }

                if useNewFormat, let expResult = explorationResult {
                    // 新格式：物品依次出现
                    for (index, reward) in expResult.rewards.enumerated() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(index) * 0.2) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                _ = visibleLootItems.insert(reward.id)
                            }
                        }
                    }
                } else if let result = result {
                    // 旧格式：数字跳动动画
                    withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                        animatedDistance = result.sessionDistance
                        animatedDuration = result.sessionDuration
                    }

                    // 物品依次出现
                    for (index, loot) in result.sessionLoot.enumerated() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(index) * 0.2) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                _ = visibleLootItems.insert(loot.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 失败状态视图

    private var failedStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 错误图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 错误标题
            Text("探索失败")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 错误信息
            Text(errorMessage ?? "探索过程中发生未知错误，请稍后重试")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // 按钮区域
            VStack(spacing: 12) {
                // 重试按钮
                if let onRetry = onRetry {
                    Button(action: {
                        dismiss()
                        onRetry()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                            Text("重新探索")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                    }
                }

                // 返回按钮
                Button(action: {
                    dismiss()
                }) {
                    Text("返回")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - 成就标题

    private var achievementHeader: some View {
        VStack(spacing: 16) {
            // 大图标（带光晕效果）
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.success.opacity(0.3),
                                ApocalypseTheme.success.opacity(0.1),
                                .clear
                            ]),
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // 内圈背景
                Circle()
                    .fill(ApocalypseTheme.success.opacity(0.2))
                    .frame(width: 100, height: 100)

                // 图标
                Image(systemName: "map.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.success)
            }

            // 标题文字
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("你的足迹已被记录")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - 统计数据卡片

    @ViewBuilder
    private var statsCard: some View {
        if let result = result {
            VStack(spacing: 0) {
                // 卡片标题
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("探索统计")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(ApocalypseTheme.cardBackground)

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 行走距离
                StatRow(
                    icon: "figure.walk",
                    iconColor: .orange,
                    title: "行走距离",
                    sessionValue: result.formattedSessionDistance,
                    totalValue: result.formattedTotalDistance,
                    rank: result.distanceRank
                )

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 探索时长（无排名）
                HStack {
                    // 左侧：图标和标题
                    HStack(spacing: 10) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.purple)
                            .frame(width: 24)

                        Text("探索时长")
                            .font(.system(size: 15))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    Spacer()

                    // 右侧：时长
                    Text(result.formattedDuration)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(ApocalypseTheme.cardBackground)

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 探索次数
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "number")
                            .font(.system(size: 16))
                            .foregroundColor(.cyan)
                            .frame(width: 24)

                        Text("累计探索")
                            .font(.system(size: 15))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    Spacer()

                    Text("\(result.totalExplorations) 次")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(ApocalypseTheme.cardBackground)
            }
            .cornerRadius(12)
        }
    }

    // MARK: - 奖励物品卡片

    @ViewBuilder
    private var rewardsCard: some View {
        if let result = result {
            VStack(spacing: 0) {
                // 卡片标题
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.warning)

                    Text("获得物品")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text("\(result.sessionLoot.count) 种")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(ApocalypseTheme.cardBackground)

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 物品列表（带动画）
                VStack(spacing: 0) {
                    ForEach(Array(result.sessionLoot.enumerated()), id: \.element.id) { index, loot in
                        RewardItemRow(
                            loot: loot,
                            isVisible: visibleLootItems.contains(loot.id)
                        )

                        if index < result.sessionLoot.count - 1 {
                            Divider()
                                .background(ApocalypseTheme.textMuted.opacity(0.2))
                                .padding(.leading, 66)
                        }
                    }
                }
                .background(ApocalypseTheme.cardBackground)

                // 底部提示
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.success)

                    Text("已添加到背包")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.success)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.success.opacity(0.1))
            }
            .cornerRadius(12)
        }
    }

    // MARK: - 确认按钮

    private var confirmButton: some View {
        Button(action: {
            dismiss()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))

                Text("确认")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ApocalypseTheme.success,
                        ApocalypseTheme.success.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: ApocalypseTheme.success.opacity(0.3), radius: 8, y: 4)
        }
    }

    // MARK: - 新格式视图组件

    /// 新格式成就标题（带奖励等级）
    private func newAchievementHeader(tier: RewardTier) -> some View {
        VStack(spacing: 16) {
            // 大图标（带光晕效果）
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                tierColor(tier).opacity(0.3),
                                tierColor(tier).opacity(0.1),
                                .clear
                            ]),
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // 内圈背景
                Circle()
                    .fill(tierColor(tier).opacity(0.2))
                    .frame(width: 100, height: 100)

                // 图标
                Image(systemName: tier.icon)
                    .font(.system(size: 50))
                    .foregroundColor(tierColor(tier))
            }

            // 标题文字
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 奖励等级
                HStack(spacing: 6) {
                    Image(systemName: tier.icon)
                        .font(.system(size: 16))
                    Text(tier.displayName)
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(tierColor(tier))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(tierColor(tier).opacity(0.2))
                )
            }
        }
        .padding(.vertical, 20)
    }

    /// 新格式统计数据卡片
    private func newStatsCard(expResult: ExplorationResult) -> some View {
        VStack(spacing: 0) {
            // 卡片标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("探索统计")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(ApocalypseTheme.cardBackground)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 行走距离
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                        .frame(width: 24)

                    Text("行走距离")
                        .font(.system(size: 15))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Text(expResult.formattedDistance)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(ApocalypseTheme.cardBackground)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 探索时长
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                        .frame(width: 24)

                    Text("探索时长")
                        .font(.system(size: 15))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Text(expResult.formattedDuration)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(ApocalypseTheme.cardBackground)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 获得物品数
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.warning)
                        .frame(width: 24)

                    Text("获得物品")
                        .font(.system(size: 15))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Text("\(expResult.rewards.count) 种")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(ApocalypseTheme.cardBackground)
        }
        .cornerRadius(12)
    }

    /// 新格式奖励物品卡片
    private func newRewardsCard(expResult: ExplorationResult) -> some View {
        VStack(spacing: 0) {
            // 卡片标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("获得物品")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(ApocalypseTheme.cardBackground)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 物品列表
            VStack(spacing: 0) {
                ForEach(Array(expResult.rewards.enumerated()), id: \.element.id) { index, reward in
                    NewRewardItemRow(
                        reward: reward,
                        definition: expResult.getItemDefinition(for: reward),
                        isVisible: visibleLootItems.contains(reward.id)
                    )

                    if index < expResult.rewards.count - 1 {
                        Divider()
                            .background(ApocalypseTheme.textMuted.opacity(0.2))
                            .padding(.leading, 66)
                    }
                }
            }
            .background(ApocalypseTheme.cardBackground)

            // 底部提示
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.success)

                Text("已添加到背包")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.success)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.success.opacity(0.1))
        }
        .cornerRadius(12)
    }

    /// 获取奖励等级颜色
    private func tierColor(_ tier: RewardTier) -> Color {
        switch tier {
        case .none: return ApocalypseTheme.textSecondary
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .diamond: return Color(red: 0.0, green: 0.8, blue: 1.0)
        }
    }
}

// MARK: - 新格式奖励物品行组件

struct NewRewardItemRow: View {
    let reward: RewardedItem
    let definition: DBItemDefinition?
    var isVisible: Bool = true

    /// 对勾弹跳状态
    @State private var checkmarkScale: CGFloat = 0

    private var categoryColor: Color {
        guard let category = definition?.category else { return .gray }
        switch category {
        case "water": return .cyan
        case "food": return .orange
        case "medical": return .red
        case "material": return .brown
        case "tool": return .gray
        case "weapon": return .purple
        case "clothing": return .blue
        default: return .secondary
        }
    }

    private var categoryIcon: String {
        guard let category = definition?.category else { return "questionmark.circle" }
        switch category {
        case "water": return "drop.fill"
        case "food": return "takeoutbag.and.cup.and.straw.fill"
        case "medical": return "cross.case.fill"
        case "material": return "cube.fill"
        case "tool": return "wrench.fill"
        case "weapon": return "shield.fill"
        case "clothing": return "tshirt.fill"
        default: return "questionmark.circle"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: definition?.icon ?? categoryIcon)
                    .font(.system(size: 20))
                    .foregroundColor(categoryColor)
            }

            // 名称和品质
            VStack(alignment: .leading, spacing: 4) {
                Text(definition?.name ?? "未知物品")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let quality = reward.quality {
                    Text(qualityDisplayName(quality))
                        .font(.system(size: 12))
                        .foregroundColor(qualityColor(quality))
                }
            }

            Spacer()

            // 数量
            Text("x\(reward.quantity)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.trailing, 8)

            // 绿色对勾（带弹跳效果）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(checkmarkScale)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : 30)
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                // 对勾弹跳动画
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1)) {
                    checkmarkScale = 1.0
                }
            }
        }
    }

    private func qualityDisplayName(_ quality: String) -> String {
        switch quality {
        case "fresh": return "新鲜"
        case "normal": return "正常"
        case "stale": return "陈旧"
        case "spoiled": return "变质"
        default: return quality
        }
    }

    private func qualityColor(_ quality: String) -> Color {
        switch quality {
        case "fresh": return .green
        case "normal": return .secondary
        case "stale": return .yellow
        case "spoiled": return .red
        default: return .secondary
        }
    }
}

// MARK: - 统计行组件

struct StatRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let sessionValue: String
    let totalValue: String
    let rank: Int

    var body: some View {
        HStack(alignment: .center) {
            // 左侧：图标
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)

            // 中间：标题和数值
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)

                HStack(spacing: 8) {
                    // 本次
                    Text(sessionValue)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 分隔
                    Text("/")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    // 累计
                    Text("累计 \(totalValue)")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // 右侧：排名
            RankBadge(rank: rank)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(ApocalypseTheme.cardBackground)
    }
}

// MARK: - 排名徽章组件

struct RankBadge: View {
    let rank: Int

    /// 排名颜色
    private var rankColor: Color {
        if rank <= 10 {
            return .orange
        } else if rank <= 50 {
            return .green
        } else if rank <= 100 {
            return .cyan
        } else {
            return ApocalypseTheme.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Text("#")
                .font(.system(size: 14, weight: .bold))
            Text("\(rank)")
                .font(.system(size: 18, weight: .bold))
        }
        .foregroundColor(rankColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(rankColor.opacity(0.15))
        .cornerRadius(8)
    }
}

// MARK: - 奖励物品行组件

struct RewardItemRow: View {
    let loot: LootRecord
    var isVisible: Bool = true

    /// 对勾弹跳状态
    @State private var checkmarkScale: CGFloat = 0

    private var definition: ItemDefinition? {
        loot.definition
    }

    private var categoryColor: Color {
        guard let category = definition?.category else { return .gray }
        switch category {
        case .water: return .cyan
        case .food: return .orange
        case .medical: return .red
        case .material: return .brown
        case .tool: return .gray
        case .weapon: return .purple
        case .clothing: return .blue
        case .misc: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: definition?.category.iconName ?? "questionmark.circle")
                    .font(.system(size: 20))
                    .foregroundColor(categoryColor)
            }

            // 名称和品质
            VStack(alignment: .leading, spacing: 4) {
                Text(definition?.name ?? "未知物品")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let quality = loot.quality {
                    Text(quality.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(qualityColor(for: quality))
                }
            }

            Spacer()

            // 数量
            Text("x\(loot.quantity)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.trailing, 8)

            // 绿色对勾（带弹跳效果）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(checkmarkScale)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : 30)
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                // 对勾弹跳动画
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1)) {
                    checkmarkScale = 1.0
                }
            }
        }
    }

    private func qualityColor(for quality: ItemQuality) -> Color {
        switch quality {
        case .fresh: return .green
        case .normal: return .secondary
        case .stale: return .yellow
        case .spoiled: return .red
        }
    }
}

// MARK: - 预览

#Preview("标准结果") {
    ExplorationResultView(result: MockExplorationResult.sampleResult)
}

#Preview("丰收结果") {
    ExplorationResultView(result: MockExplorationResult.richResult)
}

#Preview("空结果") {
    ExplorationResultView(result: MockExplorationResult.emptyResult)
}

#Preview("失败状态") {
    ExplorationResultView(
        result: nil,
        errorMessage: "网络连接失败，请检查网络后重试",
        onRetry: { print("重试") }
    )
}
