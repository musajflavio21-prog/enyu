//
//  LeaderboardView.swift
//  EarthLord
//
//  排行榜视图
//  显示各类排行榜数据
//

import SwiftUI

/// 排行榜视图
struct LeaderboardView: View {

    // MARK: - 状态

    @StateObject private var leaderboardManager = LeaderboardManager.shared

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 排行榜类型选择
                typeSelector

                // 时间范围选择
                timeRangeSelector

                // 我的排名卡片
                if let myInfo = leaderboardManager.myRankInfo {
                    myRankCard(myInfo)
                }

                // 排行榜列表
                leaderboardList
            }

            // 加载指示器
            if leaderboardManager.isLoading && leaderboardManager.entries.isEmpty {
                loadingOverlay
            }
        }
        .onAppear {
            Task {
                await leaderboardManager.loadLeaderboard()
            }
        }
    }

    // MARK: - 类型选择器

    private var typeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LeaderboardType.allCases, id: \.rawValue) { type in
                    Button {
                        Task {
                            await leaderboardManager.switchType(type)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 14))

                            Text(type.displayName)
                                .font(.subheadline)
                        }
                        .foregroundColor(leaderboardManager.currentType == type ? .white : ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(leaderboardManager.currentType == type ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    // MARK: - 时间范围选择器

    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(LeaderboardTimeRange.allCases, id: \.rawValue) { range in
                Button {
                    Task {
                        await leaderboardManager.switchTimeRange(range)
                    }
                } label: {
                    Text(range.displayName)
                        .font(.subheadline)
                        .foregroundColor(leaderboardManager.currentTimeRange == range ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            leaderboardManager.currentTimeRange == range ?
                            ApocalypseTheme.primary.opacity(0.1) :
                            Color.clear
                        )
                        .overlay(
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(leaderboardManager.currentTimeRange == range ? ApocalypseTheme.primary : Color.clear),
                            alignment: .bottom
                        )
                }
            }
        }
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 我的排名卡片

    private func myRankCard(_ info: UserLeaderboardInfo) -> some View {
        HStack(spacing: 16) {
            // 排名
            VStack(spacing: 2) {
                if let rank = info.rank {
                    Text("#\(rank)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)
                } else {
                    Text("--")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                Text("我的排名")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Divider()
                .frame(height: 40)
                .background(ApocalypseTheme.textMuted)

            // 数值
            VStack(spacing: 2) {
                Text("\(info.value)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(leaderboardManager.currentType.unit)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 百分比排名
            if let percentile = info.formattedPercentile {
                Text(percentile)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.success.opacity(0.2))
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 排行榜列表

    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(leaderboardManager.entries) { entry in
                    LeaderboardEntryRow(
                        entry: entry,
                        type: leaderboardManager.currentType,
                        isCurrentUser: entry.userId == AuthManager.shared.currentUser?.id
                    )
                }

                // 空状态
                if leaderboardManager.entries.isEmpty && !leaderboardManager.isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 50))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text("暂无排行数据")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .refreshable {
            await leaderboardManager.refresh()
        }
    }

    // MARK: - 加载指示器

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }
}

// MARK: - 排行榜条目行

struct LeaderboardEntryRow: View {
    let entry: LeaderboardEntry
    let type: LeaderboardType
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 排名
            ZStack {
                if let icon = entry.rankIcon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(rankColor)
                } else {
                    Text("\(entry.rank)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .frame(width: 40)

            // 头像
            Circle()
                .fill(isCurrentUser ? ApocalypseTheme.primary.opacity(0.3) : ApocalypseTheme.textMuted.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(entry.username?.prefix(1).uppercased() ?? "?"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isCurrentUser ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                )

            // 用户名
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username ?? "匿名玩家")
                    .font(.headline)
                    .foregroundColor(isCurrentUser ? ApocalypseTheme.primary : ApocalypseTheme.textPrimary)

                if isCurrentUser {
                    Text("我")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }

            Spacer()

            // 数值
            Text(entry.formattedValue(for: type))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(12)
        .background(isCurrentUser ? ApocalypseTheme.primary.opacity(0.1) : ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentUser ? ApocalypseTheme.primary : Color.clear, lineWidth: 1)
        )
    }

    private var rankColor: Color {
        switch entry.rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)  // 金色
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)  // 银色
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)  // 铜色
        default: return ApocalypseTheme.textSecondary
        }
    }
}

#Preview {
    LeaderboardView()
}
