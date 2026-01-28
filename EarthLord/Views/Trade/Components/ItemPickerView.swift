//
//  ItemPickerView.swift
//  EarthLord
//
//  物品选择器
//  用于在发布挂单时选择物品和数量
//

import SwiftUI

/// 物品选择模式
enum ItemPickerMode {
    case fromInventory  // 从背包选择（我要出的物品）
    case fromAll        // 从所有物品选择（我想要的物品）
}

/// 物品选择器视图
struct ItemPickerView: View {
    let mode: ItemPickerMode
    let inventoryItems: [InventoryItem]
    let definitions: [DBItemDefinition]
    @Binding var isPresented: Bool
    var excludeItemIds: [String] = []  // 已选择的物品ID（排除）
    var onSelect: (String, Int) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedItemId: String? = nil
    @State private var selectedQuantity: Int = 1

    /// 可选物品列表
    private var availableItems: [(id: String, name: String, def: DBItemDefinition?, maxQuantity: Int?)] {
        var result: [(id: String, name: String, def: DBItemDefinition?, maxQuantity: Int?)] = []

        switch mode {
        case .fromInventory:
            // 从背包选择，需要有库存
            for item in inventoryItems {
                if excludeItemIds.contains(item.itemId) { continue }
                let def = definitions.first { $0.id == item.itemId }
                result.append((item.itemId, def?.name ?? item.itemId, def, item.quantity))
            }

        case .fromAll:
            // 从所有物品定义选择
            for def in definitions {
                if excludeItemIds.contains(def.id) { continue }
                result.append((def.id, def.name, def, nil))
            }
        }

        // 按分类筛选
        if let category = selectedCategory {
            result = result.filter { $0.def?.category == category }
        }

        // 按搜索关键词筛选
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if selectedItemId == nil {
                    // 物品列表
                    itemListView
                } else {
                    // 数量选择
                    quantityPickerView
                }
            }
            .navigationTitle(selectedItemId == nil ? "选择物品" : "选择数量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if selectedItemId != nil {
                            selectedItemId = nil
                            selectedQuantity = 1
                        } else {
                            isPresented = false
                        }
                    }) {
                        if selectedItemId != nil {
                            Image(systemName: "chevron.left")
                        } else {
                            Text("取消")
                        }
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 物品列表视图

    private var itemListView: some View {
        VStack(spacing: 0) {
            // 搜索框
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // 分类筛选
            categoryFilter
                .padding(.top, 12)

            // 物品列表
            if availableItems.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(availableItems, id: \.id) { item in
                            itemRow(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    /// 搜索框
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    /// 分类筛选
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryButton(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                CategoryButton(
                    title: "食物",
                    icon: "fork.knife",
                    color: .orange,
                    isSelected: selectedCategory == "food"
                ) {
                    selectedCategory = "food"
                }

                CategoryButton(
                    title: "水",
                    icon: "drop.fill",
                    color: .cyan,
                    isSelected: selectedCategory == "water"
                ) {
                    selectedCategory = "water"
                }

                CategoryButton(
                    title: "材料",
                    icon: "cube.fill",
                    color: .brown,
                    isSelected: selectedCategory == "material"
                ) {
                    selectedCategory = "material"
                }

                CategoryButton(
                    title: "工具",
                    icon: "wrench.and.screwdriver.fill",
                    color: .gray,
                    isSelected: selectedCategory == "tool"
                ) {
                    selectedCategory = "tool"
                }

                CategoryButton(
                    title: "医疗",
                    icon: "cross.case.fill",
                    color: .red,
                    isSelected: selectedCategory == "medical"
                ) {
                    selectedCategory = "medical"
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// 物品行
    private func itemRow(item: (id: String, name: String, def: DBItemDefinition?, maxQuantity: Int?)) -> some View {
        let icon = item.def?.icon ?? categoryIcon(for: item.def?.category)
        let color = categoryColor(for: item.def?.category)

        return Button(action: {
            selectedItemId = item.id
            selectedQuantity = 1
        }) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }

                // 物品名称
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if let max = item.maxQuantity {
                        Text("库存: \(max)")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 空状态
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: mode == .fromInventory ? "bag" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(mode == .fromInventory ? "背包中没有可用物品" : "没有找到相关物品")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - 数量选择视图

    private var quantityPickerView: some View {
        let item = availableItems.first { $0.id == selectedItemId }
        let def = item?.def
        let maxQty = item?.maxQuantity

        return VStack(spacing: 30) {
            Spacer()

            // 物品图标
            ZStack {
                Circle()
                    .fill(categoryColor(for: def?.category).opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: def?.icon ?? categoryIcon(for: def?.category))
                    .font(.system(size: 36))
                    .foregroundColor(categoryColor(for: def?.category))
            }

            // 物品名称
            Text(item?.name ?? "未知物品")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 库存提示
            if let max = maxQty {
                Text("库存中有: \(max) 个")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 数量选择器
            HStack(spacing: 30) {
                // 减少
                Button(action: {
                    if selectedQuantity > 1 {
                        selectedQuantity -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(selectedQuantity > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                }
                .disabled(selectedQuantity <= 1)

                // 数量
                Text("\(selectedQuantity)")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(minWidth: 80)

                // 增加
                Button(action: {
                    if let max = maxQty {
                        if selectedQuantity < max {
                            selectedQuantity += 1
                        }
                    } else {
                        selectedQuantity += 1
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(canIncrease(maxQty) ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                }
                .disabled(!canIncrease(maxQty))
            }

            Spacer()

            // 确认按钮
            Button(action: {
                if let itemId = selectedItemId {
                    onSelect(itemId, selectedQuantity)
                    isPresented = false
                }
            }) {
                Text("确认添加")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private func canIncrease(_ maxQty: Int?) -> Bool {
        if let max = maxQty {
            return selectedQuantity < max
        }
        return true
    }

    // MARK: - 辅助方法

    private func categoryIcon(for category: String?) -> String {
        guard let category = category else { return "questionmark.circle" }
        switch category {
        case "water": return "drop.fill"
        case "food": return "fork.knife"
        case "medical": return "cross.case.fill"
        case "material": return "cube.fill"
        case "tool": return "wrench.and.screwdriver.fill"
        default: return "questionmark.circle"
        }
    }

    private func categoryColor(for category: String?) -> Color {
        guard let category = category else { return .gray }
        switch category {
        case "water": return .cyan
        case "food": return .orange
        case "medical": return .red
        case "material": return .brown
        case "tool": return .gray
        default: return .secondary
        }
    }
}

// MARK: - 预览

#Preview {
    ItemPickerView(
        mode: .fromAll,
        inventoryItems: [],
        definitions: [],
        isPresented: .constant(true),
        onSelect: { _, _ in }
    )
}
