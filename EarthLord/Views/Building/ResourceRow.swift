//
//  ResourceRow.swift
//  EarthLord
//
//  资源行组件
//  显示单个资源的需求和当前持有量
//

import SwiftUI

/// 资源行视图
struct ResourceRow: View {

    // MARK: - 属性

    /// 资源 ID（如 "wood", "stone"）
    let resourceId: String

    /// 需要数量
    let required: Int

    /// 当前持有数量
    let current: Int

    // MARK: - 计算属性

    /// 是否足够
    private var isSufficient: Bool {
        current >= required
    }

    /// 资源显示名称
    private var resourceName: String {
        switch resourceId {
        // UUID 映射
        case "79d5cc71-d98a-46ef-9a4b-4a7d7c1c0495": return "木材"
        case "419e6e21-dc02-4bd4-94bb-1fcb9c08f738": return "石头"
        case "dd722a71-ba35-4cf8-92d3-356bc10f0b35": return "金属"
        case "de93eab2-daa0-43dc-b33a-1f21496ebc31": return "玻璃"
        // 保留旧的简单字符串映射以兼容
        case "wood": return "木材"
        case "stone": return "石头"
        case "metal": return "金属"
        case "glass": return "玻璃"
        case "food": return "食物"
        case "water": return "水"
        default: return resourceId
        }
    }

    /// 资源图标
    private var resourceIcon: String {
        switch resourceId {
        // UUID 映射
        case "79d5cc71-d98a-46ef-9a4b-4a7d7c1c0495": return "tree.fill"
        case "419e6e21-dc02-4bd4-94bb-1fcb9c08f738": return "mountain.2.fill"
        case "dd722a71-ba35-4cf8-92d3-356bc10f0b35": return "gearshape.fill"
        case "de93eab2-daa0-43dc-b33a-1f21496ebc31": return "rectangle.portrait.fill"
        // 保留旧的简单字符串映射以兼容
        case "wood": return "tree.fill"
        case "stone": return "mountain.2.fill"
        case "metal": return "gearshape.fill"
        case "glass": return "rectangle.portrait.fill"
        case "food": return "carrot.fill"
        case "water": return "drop.fill"
        default: return "cube.fill"
        }
    }

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 12) {
            // 资源图标
            Image(systemName: resourceIcon)
                .foregroundColor(isSufficient ? .green : .red)
                .frame(width: 24)

            // 资源名称
            Text(resourceName)
                .foregroundColor(.white)
                .frame(width: 50, alignment: .leading)

            Spacer()

            // 数量显示
            HStack(spacing: 4) {
                Text("\(current)")
                    .foregroundColor(isSufficient ? .green : .red)
                    .fontWeight(.semibold)

                Text("/")
                    .foregroundColor(.gray)

                Text("\(required)")
                    .foregroundColor(.gray)
            }
            .font(.subheadline)

            // 状态图标
            Image(systemName: isSufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSufficient ? .green : .red)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 0) {
        ResourceRow(resourceId: "wood", required: 30, current: 50)
        Divider().background(Color.gray.opacity(0.3))
        ResourceRow(resourceId: "stone", required: 20, current: 10)
        Divider().background(Color.gray.opacity(0.3))
        ResourceRow(resourceId: "metal", required: 40, current: 40)
    }
    .padding()
    .background(Color.black)
}
