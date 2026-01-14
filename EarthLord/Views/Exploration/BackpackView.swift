//
//  BackpackView.swift
//  EarthLord
//
//  背包管理页面
//  显示玩家背包中的物品，支持搜索、筛选、使用和存储
//

import SwiftUI

struct BackpackView: View {

    // MARK: - 状态属性

    /// 背包管理器
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 搜索关键词
    @State private var searchText = ""

    /// 当前选中的分类（nil 表示全部）
    @State private var selectedCategory: String? = nil

    /// 动画显示的容量百分比
    @State private var animatedCapacity: Double = 0

    /// 列表项可见状态
    @State private var visibleItems: Set<UUID> = []

    /// 正在操作的物品
    @State private var operatingItemId: UUID?

    // MARK: - 计算属性

    /// 容量进度条颜色
    private var capacityColor: Color {
        if inventoryManager.volumePercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if inventoryManager.volumePercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    /// 筛选后的物品列表
    private var filteredItems: [InventoryItem] {
        var result = inventoryManager.items

        // 按分类筛选
        if let category = selectedCategory {
            result = result.filter { item in
                guard let def = item.getDefinition(from: inventoryManager.itemDefinitions) else { return false }
                return def.category == category
            }
        }

        // 按搜索关键词筛选
        if !searchText.isEmpty {
            result = result.filter { item in
                guard let def = item.getDefinition(from: inventoryManager.itemDefinitions) else { return false }
                return def.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    // MARK: - 主视图

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 容量状态卡
                capacityCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 搜索框
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 分类筛选
                categoryFilter
                    .padding(.top, 12)

                // 物品列表
                itemListView
                    .padding(.top, 12)
            }

            // 加载中
            if inventoryManager.isLoading {
                loadingOverlay
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await inventoryManager.loadInventory()
        }
        .alert("错误", isPresented: .constant(inventoryManager.errorMessage != nil)) {
            Button("确定") {
                inventoryManager.clearError()
            }
        } message: {
            if let error = inventoryManager.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - 加载中遮罩

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(ApocalypseTheme.primary)

                Text("加载中...")
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(30)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - 容量状态卡

    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "bag.fill")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("背包容量")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(String(format: "%.1f", inventoryManager.currentVolume)) / \(Int(inventoryManager.maxVolume))")
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 进度条（带动画）
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.background)
                        .frame(height: 12)

                    // 进度（使用动画值）
                    RoundedRectangle(cornerRadius: 6)
                        .fill(capacityColor)
                        .frame(width: geometry.size.width * animatedCapacity, height: 12)
                }
            }
            .frame(height: 12)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedCapacity = inventoryManager.volumePercentage
                }
            }
            .onChange(of: inventoryManager.volumePercentage) { _, newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    animatedCapacity = newValue
                }
            }

            // 重量信息
            HStack {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 12))
                Text("\(String(format: "%.1f", inventoryManager.currentWeight)) / \(Int(inventoryManager.maxWeight)) kg")
                    .font(.system(size: 13))

                Spacer()

                // 物品数量
                Text("\(inventoryManager.items.count) 种物品")
                    .font(.system(size: 13))
            }
            .foregroundColor(ApocalypseTheme.textMuted)

            // 警告文字
            if inventoryManager.isFull {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("背包已满！")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.danger)
            } else if inventoryManager.volumePercentage > 0.9 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("背包快满了！")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.danger)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
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

    // MARK: - 分类筛选

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部
                CategoryButton(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                // 食物
                CategoryButton(
                    title: "食物",
                    icon: "fork.knife",
                    color: .orange,
                    isSelected: selectedCategory == "food"
                ) {
                    selectedCategory = "food"
                }

                // 水
                CategoryButton(
                    title: "水",
                    icon: "drop.fill",
                    color: .cyan,
                    isSelected: selectedCategory == "water"
                ) {
                    selectedCategory = "water"
                }

                // 材料
                CategoryButton(
                    title: "材料",
                    icon: "cube.fill",
                    color: .brown,
                    isSelected: selectedCategory == "material"
                ) {
                    selectedCategory = "material"
                }

                // 工具
                CategoryButton(
                    title: "工具",
                    icon: "wrench.and.screwdriver.fill",
                    color: .gray,
                    isSelected: selectedCategory == "tool"
                ) {
                    selectedCategory = "tool"
                }

                // 医疗
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

    // MARK: - 物品列表

    @ViewBuilder
    private var itemListView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        let delayTime = 0.05 * Double(index)
                        BackpackItemCardNew(
                            item: item,
                            definitions: inventoryManager.itemDefinitions,
                            isOperating: operatingItemId == item.id,
                            onUse: {
                                Task {
                                    operatingItemId = item.id
                                    _ = await inventoryManager.useItem(item)
                                    operatingItemId = nil
                                }
                            },
                            onDiscard: {
                                Task {
                                    operatingItemId = item.id
                                    _ = await inventoryManager.discardItem(item)
                                    operatingItemId = nil
                                }
                            }
                        )
                        .opacity(visibleItems.contains(item.id) ? 1 : 0)
                        .offset(y: visibleItems.contains(item.id) ? 0 : 15)
                        .onAppear {
                            withAnimation(Animation.easeOut(duration: 0.25).delay(delayTime)) {
                                _ = visibleItems.insert(item.id)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .refreshable {
            await inventoryManager.loadInventory()
        }
        .onChange(of: selectedCategory) { _, _ in
            // 切换分类时重置动画
            visibleItems.removeAll()
        }
        .onChange(of: searchText) { _, _ in
            // 搜索时重置动画
            visibleItems.removeAll()
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            // 根据情况显示不同的空状态
            if inventoryManager.items.isEmpty {
                // 背包完全空
                Image(systemName: "bag")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("背包空空如也")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("去探索收集物资吧")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)

            } else if !searchText.isEmpty {
                // 搜索没有结果
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("没有找到相关物品")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("尝试其他搜索关键词")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)

            } else {
                // 筛选后没有结果
                Image(systemName: "tray")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("该分类下没有物品")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("尝试选择其他分类")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

// MARK: - 分类按钮组件

struct CategoryButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color : ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - 物品卡片组件（新版，使用数据库数据）

struct BackpackItemCardNew: View {
    let item: InventoryItem
    let definitions: [DBItemDefinition]
    let isOperating: Bool
    let onUse: () -> Void
    let onDiscard: () -> Void

    /// 物品定义
    private var definition: DBItemDefinition? {
        item.getDefinition(from: definitions)
    }

    /// 分类图标
    private var categoryIcon: String {
        guard let category = definition?.category else { return "questionmark.circle" }
        switch category {
        case "water": return "drop.fill"
        case "food": return "fork.knife"
        case "medical": return "cross.case.fill"
        case "material": return "cube.fill"
        case "tool": return "wrench.and.screwdriver.fill"
        default: return "questionmark.circle"
        }
    }

    /// 分类颜色
    private var categoryColor: Color {
        guard let category = definition?.category else { return .gray }
        switch category {
        case "water": return .cyan
        case "food": return .orange
        case "medical": return .red
        case "material": return .brown
        case "tool": return .gray
        default: return .secondary
        }
    }

    /// 稀有度颜色
    private var rarityColor: Color {
        guard let rarity = definition?.rarity else { return .gray }
        switch rarity {
        case "common": return .gray
        case "uncommon": return .green
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .gray
        }
    }

    /// 稀有度显示名称
    private var rarityDisplayName: String {
        guard let rarity = definition?.rarity else { return "普通" }
        switch rarity {
        case "common": return "普通"
        case "uncommon": return "优良"
        case "rare": return "稀有"
        case "epic": return "史诗"
        case "legendary": return "传说"
        default: return rarity
        }
    }

    /// 品质颜色
    private var qualityColor: Color {
        guard let quality = item.quality else { return .gray }
        switch quality {
        case "fresh": return .green
        case "normal": return .secondary
        case "stale": return .yellow
        case "spoiled": return .red
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // 左侧：分类图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: definition?.icon ?? categoryIcon)
                    .font(.system(size: 22))
                    .foregroundColor(categoryColor)
            }

            // 中间：物品信息
            VStack(alignment: .leading, spacing: 6) {
                // 名称和数量
                HStack(spacing: 8) {
                    Text(definition?.name ?? "未知物品")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("x\(item.quantity)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 详情行
                HStack(spacing: 10) {
                    // 重量
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 10))
                        Text(String(format: "%.1fkg", item.totalWeight(from: definitions)))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(ApocalypseTheme.textMuted)

                    // 品质（如果有）
                    if let qualityName = item.qualityDisplayName {
                        Text(qualityName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(qualityColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(qualityColor.opacity(0.15))
                            .cornerRadius(4)
                    }

                    // 稀有度标签
                    Text(rarityDisplayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(rarityColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rarityColor.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            Spacer()

            // 右侧：操作按钮
            if isOperating {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 60)
            } else {
                VStack(spacing: 8) {
                    // 使用按钮
                    Button(action: onUse) {
                        Text("使用")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(6)
                    }

                    // 丢弃按钮
                    Button(action: onDiscard) {
                        Text("丢弃")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ApocalypseTheme.background)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(ApocalypseTheme.textMuted, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - 兼容旧版的物品卡片（用于预览）

struct BackpackItemCard: View {
    let item: BackpackItem

    /// 物品定义
    private var definition: ItemDefinition? {
        item.definition
    }

    /// 分类图标
    private var categoryIcon: String {
        definition?.category.iconName ?? "questionmark.circle"
    }

    /// 分类颜色
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

    /// 稀有度颜色
    private var rarityColor: Color {
        guard let rarity = definition?.rarity else { return .gray }
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    /// 品质文字
    private var qualityText: String? {
        guard let quality = item.quality else { return nil }
        return quality.rawValue
    }

    /// 品质颜色
    private var qualityColor: Color {
        guard let quality = item.quality else { return .gray }
        switch quality {
        case .fresh: return .green
        case .normal: return .secondary
        case .stale: return .yellow
        case .spoiled: return .red
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // 左侧：分类图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: categoryIcon)
                    .font(.system(size: 22))
                    .foregroundColor(categoryColor)
            }

            // 中间：物品信息
            VStack(alignment: .leading, spacing: 6) {
                // 名称和数量
                HStack(spacing: 8) {
                    Text(definition?.name ?? "未知物品")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("x\(item.quantity)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 详情行
                HStack(spacing: 10) {
                    // 重量
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 10))
                        Text(String(format: "%.1fkg", item.totalWeight))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(ApocalypseTheme.textMuted)

                    // 品质（如果有）
                    if let qualityText = qualityText {
                        Text(qualityText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(qualityColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(qualityColor.opacity(0.15))
                            .cornerRadius(4)
                    }

                    // 稀有度标签
                    if let rarity = definition?.rarity {
                        Text(rarity.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(rarityColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rarityColor.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            // 右侧：操作按钮
            VStack(spacing: 8) {
                // 使用按钮
                Button(action: {
                    print("🎒 [背包] 使用物品: \(definition?.name ?? "未知")")
                    print("   - 数量: \(item.quantity)")
                    print("   - 品质: \(item.quality?.rawValue ?? "无")")
                }) {
                    Text("使用")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(6)
                }

                // 存储按钮
                Button(action: {
                    print("🎒 [背包] 存储物品: \(definition?.name ?? "未知")")
                    print("   - 数量: \(item.quantity)")
                }) {
                    Text("存储")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ApocalypseTheme.background)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ApocalypseTheme.textMuted, lineWidth: 1)
                        )
                }
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        BackpackView()
    }
}
