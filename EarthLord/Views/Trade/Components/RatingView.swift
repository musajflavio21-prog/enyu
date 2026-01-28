//
//  RatingView.swift
//  EarthLord
//
//  评分组件
//  用于显示和选择1-5星评分
//

import SwiftUI

/// 评分视图
struct RatingView: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    var isEditable: Bool = true
    var starSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: starSize))
                    .foregroundColor(index <= rating ? .yellow : ApocalypseTheme.textMuted)
                    .onTapGesture {
                        if isEditable {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                rating = index
                            }
                        }
                    }
            }
        }
    }
}

/// 只读评分显示
struct RatingDisplayView: View {
    let rating: Int
    var maxRating: Int = 5
    var starSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: starSize))
                    .foregroundColor(index <= rating ? .yellow : ApocalypseTheme.textMuted)
            }
        }
    }
}

// MARK: - 评价弹窗

struct RatingSheetView: View {
    let historyId: UUID
    let partnerUsername: String
    @Binding var isPresented: Bool
    var onSubmit: (Int, String?) -> Void

    @State private var rating: Int = 0
    @State private var comment: String = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 24) {
            // 标题
            Text("评价交易")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 交易对象
            HStack(spacing: 4) {
                Text("与")
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("@\(partnerUsername)")
                    .foregroundColor(ApocalypseTheme.primary)
                    .fontWeight(.medium)
                Text("的交易")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .font(.system(size: 15))

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 评分选择
            VStack(spacing: 12) {
                Text("请给这次交易打分")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                RatingView(rating: $rating)
            }

            // 评语输入
            VStack(alignment: .leading, spacing: 8) {
                Text("评语（可选）")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                TextEditor(text: $comment)
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(height: 80)
                    .padding(10)
                    .background(ApocalypseTheme.background)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                    )
            }

            // 按钮
            HStack(spacing: 16) {
                // 取消按钮
                Button(action: { isPresented = false }) {
                    Text("取消")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ApocalypseTheme.background)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(ApocalypseTheme.textMuted, lineWidth: 1)
                        )
                }

                // 提交按钮
                Button(action: submitRating) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("提交评价")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(rating > 0 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                .cornerRadius(10)
                .disabled(rating == 0 || isSubmitting)
            }
        }
        .padding(24)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(20)
        .padding(.horizontal, 20)
    }

    private func submitRating() {
        isSubmitting = true
        onSubmit(rating, comment.isEmpty ? nil : comment)
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 30) {
        RatingView(rating: .constant(3))

        RatingDisplayView(rating: 4)

        RatingSheetView(
            historyId: UUID(),
            partnerUsername: "TestUser",
            isPresented: .constant(true),
            onSubmit: { _, _ in }
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
