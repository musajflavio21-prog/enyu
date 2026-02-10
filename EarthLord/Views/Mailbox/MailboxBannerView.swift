//
//  MailboxBannerView.swift
//  EarthLord
//
//  邮箱横幅组件 - 显示在个人页面中
//

import SwiftUI

struct MailboxBannerView: View {
    @ObservedObject var mailboxManager: MailboxManager
    let onTap: () -> Void

    var body: some View {
        if mailboxManager.pendingCount > 0 {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // 邮箱图标
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "tray.full.fill")
                            .font(.title2)
                            .foregroundColor(ApocalypseTheme.warning)

                        // 红点
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 4, y: -4)
                    }
                    .frame(width: 32)

                    // 文字
                    VStack(alignment: .leading, spacing: 2) {
                        Text("物资邮箱")
                            .font(.body.bold())
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("\(mailboxManager.pendingCount)件物资待领取")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.warning)
                    }

                    Spacer()

                    // 箭头
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ApocalypseTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ApocalypseTheme.warning.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
}
