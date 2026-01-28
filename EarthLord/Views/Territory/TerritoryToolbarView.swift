//
//  TerritoryToolbarView.swift
//  EarthLord
//
//  领地悬浮工具栏
//  提供快捷操作按钮
//

import SwiftUI

/// 领地工具栏视图
struct TerritoryToolbarView: View {

    // MARK: - 属性

    /// 添加建筑回调
    var onAddBuilding: (() -> Void)?

    /// 编辑领地名称回调
    var onEditName: (() -> Void)?

    /// 删除领地回调
    var onDelete: (() -> Void)?

    /// 定位到领地中心回调
    var onLocate: (() -> Void)?

    // MARK: - 状态

    /// 是否展开工具栏
    @State private var isExpanded = false

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 12) {
            // 展开的按钮
            if isExpanded {
                // 删除按钮
                ToolbarButton(
                    icon: "trash.fill",
                    color: .red,
                    action: { onDelete?() }
                )

                // 编辑名称按钮
                ToolbarButton(
                    icon: "pencil",
                    color: .orange,
                    action: { onEditName?() }
                )

                // 定位按钮
                ToolbarButton(
                    icon: "location.fill",
                    color: .blue,
                    action: { onLocate?() }
                )

                // 添加建筑按钮
                ToolbarButton(
                    icon: "plus.circle.fill",
                    color: .green,
                    action: { onAddBuilding?() }
                )
            }

            // 主按钮（展开/收起）
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "xmark" : "ellipsis")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(isExpanded ? Color.gray : Color.green)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - 工具栏按钮

/// 工具栏单个按钮
private struct ToolbarButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(color)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - 预览

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                TerritoryToolbarView(
                    onAddBuilding: { print("Add building") },
                    onEditName: { print("Edit name") },
                    onDelete: { print("Delete") },
                    onLocate: { print("Locate") }
                )
            }
        }
    }
}
