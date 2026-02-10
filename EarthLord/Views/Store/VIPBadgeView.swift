//
//  VIPBadgeView.swift
//  EarthLord
//
//  VIP徽章组件
//  用于聊天、排行榜、个人页等位置显示VIP等级
//

import SwiftUI

/// VIP徽章视图
struct VIPBadgeView: View {
    let tier: VIPTier

    var body: some View {
        if tier != .none {
            HStack(spacing: 3) {
                Image(systemName: tier.iconName)
                    .font(.system(size: 10, weight: .bold))
                Text(tier == .survivor ? "VIP" : "LORD")
                    .font(.system(size: 9, weight: .heavy))
            }
            .foregroundColor(badgeTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeBackground)
            .cornerRadius(4)
        }
    }

    private var badgeTextColor: Color {
        switch tier {
        case .none: return .clear
        case .survivor: return .white
        case .lord: return Color(red: 0.15, green: 0.1, blue: 0)
        }
    }

    private var badgeBackground: some View {
        Group {
            switch tier {
            case .none:
                Color.clear
            case .survivor:
                LinearGradient(
                    colors: [Color.green, Color.green.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .lord:
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.84, blue: 0), Color(red: 1.0, green: 0.65, blue: 0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }
}

/// 大号VIP徽章（用于个人页）
struct VIPBadgeLargeView: View {
    let tier: VIPTier

    var body: some View {
        if tier != .none {
            HStack(spacing: 6) {
                Image(systemName: tier.iconName)
                    .font(.system(size: 16, weight: .bold))
                Text(tier.displayName)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(tier == .lord ? Color(red: 0.15, green: 0.1, blue: 0) : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                tier == .lord
                    ? LinearGradient(colors: [Color(red: 1.0, green: 0.84, blue: 0), Color(red: 1.0, green: 0.65, blue: 0)], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(8)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        VIPBadgeView(tier: .none)
        VIPBadgeView(tier: .survivor)
        VIPBadgeView(tier: .lord)
        VIPBadgeLargeView(tier: .survivor)
        VIPBadgeLargeView(tier: .lord)
    }
    .padding()
    .background(Color.black)
}
