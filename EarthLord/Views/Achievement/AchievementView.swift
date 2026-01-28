//
//  AchievementView.swift
//  EarthLord
//
//  成就列表视图
//  显示所有成就及进度
//

import SwiftUI

/// 成就视图
struct AchievementView: View {

    // MARK: - 状态

    @StateObject private var achievementManager = AchievementManager.shared

    /// 当前选中的类别
    @State private var selectedCategory: AchievementCategory?

    /// 是否显示成就详情
    @State private var showDetail = false

    /// 选中的成就
    @State private var selectedAchievement: AchievementDefinition?

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部统计
                statsHeader

                // 类别选择器
                categorySelector

                // 成就列表
                achievementList
            }

            // 成就解锁通知
            if let achievement = achievementManager.recentlyUnlocked {
                achievementUnlockOverlay(achievement)
            }
        }
        .onAppear {
            Task {
                await achievementManager.loadUserAchievements()
            }
        }
        .sheet(isPresented: $showDetail) {
            if let achievement = selectedAchievement {
                AchievementDetailSheet(achievement: achievement)
            }
        }
    }

    // MARK: - 统计头部

    private var statsHeader: some View {
        HStack(spacing: 20) {
            // 完成数量
            VStack(spacing: 4) {
                Text("\(achievementManager.completedCount())")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("已完成")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 进度环
            ZStack {
                Circle()
                    .stroke(ApocalypseTheme.textMuted, lineWidth: 8)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: achievementManager.overallProgress())
                    .stroke(ApocalypseTheme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(achievementManager.overallProgress() * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 未领取奖励
            VStack(spacing: 4) {
                Text("\(achievementManager.unclaimedCount)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(achievementManager.unclaimedCount > 0 ? ApocalypseTheme.warning : ApocalypseTheme.textSecondary)

                Text("待领取")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 类别选择器

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 全部
                AchievementCategoryButton(
                    title: "全部",
                    iconName: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                // 各类别
                ForEach(AchievementCategory.allCases, id: \.rawValue) { category in
                    AchievementCategoryButton(
                        title: category.displayName,
                        iconName: category.iconName,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    // MARK: - 成就列表

    private var achievementList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredAchievements, id: \.id) { achievement in
                    AchievementCard(
                        achievement: achievement,
                        progress: achievementManager.getProgress(for: achievement.id)
                    ) {
                        selectedAchievement = achievement
                        showDetail = true
                    }
                }
            }
            .padding(16)
        }
    }

    /// 过滤后的成就列表
    private var filteredAchievements: [AchievementDefinition] {
        if let category = selectedCategory {
            return achievementManager.achievements.filter { $0.category == category }
        }
        return achievementManager.achievements
    }

    // MARK: - 成就解锁通知

    private func achievementUnlockOverlay(_ achievement: AchievementDefinition) -> some View {
        VStack {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("成就解锁")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(achievement.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.primary)

                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(24)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5))
        .onTapGesture {
            achievementManager.clearRecentlyUnlocked()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                achievementManager.clearRecentlyUnlocked()
            }
        }
    }
}

// MARK: - 类别按钮

struct AchievementCategoryButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 14))

                Text(title)
                    .font(.subheadline)
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }
}

// MARK: - 成就卡片

struct AchievementCard: View {
    let achievement: AchievementDefinition
    let progress: UserAchievement?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 图标
                ZStack {
                    Circle()
                        .fill(rarityColor.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: achievement.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(isCompleted ? rarityColor : ApocalypseTheme.textMuted)
                }

                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(achievement.name)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        // 稀有度标签
                        Text(achievement.rarity.displayName)
                            .font(.system(size: 10))
                            .foregroundColor(rarityColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rarityColor.opacity(0.2))
                            .cornerRadius(8)
                    }

                    Text(achievement.description)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(1)

                    // 进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                                .frame(height: 4)
                                .cornerRadius(2)

                            Rectangle()
                                .fill(isCompleted ? ApocalypseTheme.success : ApocalypseTheme.primary)
                                .frame(width: geometry.size.width * progressPercentage, height: 4)
                                .cornerRadius(2)
                        }
                    }
                    .frame(height: 4)
                }

                Spacer()

                // 状态指示
                if isCompleted {
                    if progress?.rewardClaimed == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.success)
                    } else {
                        Image(systemName: "gift.fill")
                            .foregroundColor(ApocalypseTheme.warning)
                    }
                } else {
                    Text("\(currentValue)/\(achievement.targetValue)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    private var isCompleted: Bool {
        progress?.isCompleted ?? false
    }

    private var currentValue: Int {
        progress?.currentValue ?? 0
    }

    private var progressPercentage: Double {
        guard achievement.targetValue > 0 else { return 0 }
        return min(1.0, Double(currentValue) / Double(achievement.targetValue))
    }

    private var rarityColor: Color {
        switch achievement.rarity {
        case .common: return ApocalypseTheme.textSecondary
        case .uncommon: return ApocalypseTheme.success
        case .rare: return ApocalypseTheme.info
        case .epic: return Color.purple
        case .legendary: return ApocalypseTheme.primary
        }
    }
}

// MARK: - 成就详情弹窗

struct AchievementDetailSheet: View {
    let achievement: AchievementDefinition

    @StateObject private var achievementManager = AchievementManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isClaiming = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 图标
                        ZStack {
                            Circle()
                                .fill(rarityColor.opacity(0.2))
                                .frame(width: 100, height: 100)

                            Image(systemName: achievement.iconName)
                                .font(.system(size: 50))
                                .foregroundColor(isCompleted ? rarityColor : ApocalypseTheme.textMuted)
                        }
                        .padding(.top, 20)

                        // 名称和描述
                        VStack(spacing: 8) {
                            Text(achievement.name)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text(achievement.rarity.displayName)
                                .font(.subheadline)
                                .foregroundColor(rarityColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(rarityColor.opacity(0.2))
                                .cornerRadius(12)

                            Text(achievement.description)
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // 进度
                        VStack(spacing: 8) {
                            Text("进度")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("\(currentValue) / \(achievement.targetValue)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(isCompleted ? ApocalypseTheme.success : ApocalypseTheme.primary)

                            // 进度条
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(ApocalypseTheme.textMuted.opacity(0.3))
                                        .frame(height: 8)
                                        .cornerRadius(4)

                                    Rectangle()
                                        .fill(isCompleted ? ApocalypseTheme.success : ApocalypseTheme.primary)
                                        .frame(width: geometry.size.width * progressPercentage, height: 8)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(height: 8)
                            .padding(.horizontal, 40)
                        }

                        // 奖励
                        VStack(spacing: 12) {
                            Text("奖励")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            HStack(spacing: 20) {
                                VStack {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(ApocalypseTheme.warning)
                                    Text("+\(achievement.expReward) 经验")
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }
                            }
                        }
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // 领取按钮
                        if isCompleted && !(progress?.rewardClaimed ?? false) {
                            Button {
                                claimReward()
                            } label: {
                                HStack {
                                    if isClaiming {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "gift.fill")
                                        Text("领取奖励")
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(ApocalypseTheme.primary)
                                .cornerRadius(12)
                            }
                            .disabled(isClaiming)
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("成就详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    private var progress: UserAchievement? {
        achievementManager.getProgress(for: achievement.id)
    }

    private var isCompleted: Bool {
        progress?.isCompleted ?? false
    }

    private var currentValue: Int {
        progress?.currentValue ?? 0
    }

    private var progressPercentage: Double {
        guard achievement.targetValue > 0 else { return 0 }
        return min(1.0, Double(currentValue) / Double(achievement.targetValue))
    }

    private var rarityColor: Color {
        switch achievement.rarity {
        case .common: return ApocalypseTheme.textSecondary
        case .uncommon: return ApocalypseTheme.success
        case .rare: return ApocalypseTheme.info
        case .epic: return Color.purple
        case .legendary: return ApocalypseTheme.primary
        }
    }

    private func claimReward() {
        isClaiming = true
        Task {
            _ = await achievementManager.claimReward(achievementId: achievement.id)
            isClaiming = false
        }
    }
}

#Preview {
    AchievementView()
}
