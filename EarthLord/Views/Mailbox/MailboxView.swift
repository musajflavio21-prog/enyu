//
//  MailboxView.swift
//  EarthLord
//
//  待领取物资邮箱页面
//

import SwiftUI

struct MailboxView: View {
    @StateObject private var mailboxManager = MailboxManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showCapacityAlert = false
    @State private var capacityAlertMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if mailboxManager.isLoading && mailboxManager.pendingItems.isEmpty {
                    ProgressView("加载中...")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else if mailboxManager.pendingItems.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // 背包容量指示条
                            capacityBar

                            // 物品列表按来源分组
                            ForEach(groupedItems, id: \.key) { group in
                                sectionView(title: group.key, items: group.items)
                            }

                            // 全部领取按钮
                            claimAllButton
                                .padding(.top, 8)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("待领取物资")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("容量不足", isPresented: $showCapacityAlert) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text(capacityAlertMessage)
            }
            .task {
                await inventoryManager.loadItemDefinitions()
                await inventoryManager.loadInventory()
                await mailboxManager.loadPendingItems()
            }
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("没有待领取的物资")
                .font(.title3)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("购买物资包后，物品会发送到这里")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
    }

    // MARK: - 背包容量指示条

    private var capacityBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bag.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("背包容量")
                    .font(.subheadline.bold())
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(String(format: "%.1f", inventoryManager.currentWeight)) / \(String(format: "%.0f", inventoryManager.maxWeight)) kg")
                    .font(.subheadline)
                    .foregroundColor(capacityColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(capacityColor)
                        .frame(width: geo.size.width * inventoryManager.weightPercentage, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    private var capacityColor: Color {
        let pct = inventoryManager.weightPercentage
        if pct >= 0.9 { return ApocalypseTheme.danger }
        if pct >= 0.7 { return ApocalypseTheme.warning }
        return ApocalypseTheme.success
    }

    // MARK: - 分组数据

    private struct ItemGroup {
        let key: String
        let items: [PendingItem]
    }

    private var groupedItems: [ItemGroup] {
        let dict = Dictionary(grouping: mailboxManager.pendingItems) { $0.sourceDisplay }
        return dict.map { ItemGroup(key: $0.key, items: $0.value) }
            .sorted { $0.items.first?.createdAt ?? Date.distantPast > $1.items.first?.createdAt ?? Date.distantPast }
    }

    // MARK: - 分组视图

    private func sectionView(title: String, items: [PendingItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 分组标题
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(ApocalypseTheme.primary)
                Spacer()
                Text("\(items.count)种物品")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))

            // 物品行
            ForEach(items) { item in
                itemRow(item)
                if item.id != items.last?.id {
                    Divider()
                        .background(ApocalypseTheme.textSecondary.opacity(0.1))
                        .padding(.leading, 56)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 物品行

    private func itemRow(_ item: PendingItem) -> some View {
        let itemDef = inventoryManager.itemDefinitions.first { $0.id == item.itemId }
        let iconName = itemDef?.icon ?? "shippingbox.fill"
        let displayName = itemDef?.name ?? item.itemId
        let weight = (itemDef?.weight ?? 0) * Double(item.quantity)

        return HStack(spacing: 12) {
            // 图标
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 36, height: 36)

            // 名称和信息
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("x\(item.quantity)  \(String(format: "%.1f", weight))kg")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 领取按钮
            Button(action: {
                Task {
                    await claimSingleItem(item)
                }
            }) {
                Text("领取")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ApocalypseTheme.primary)
                    )
            }
            .disabled(mailboxManager.isClaiming)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - 全部领取按钮

    private var claimAllButton: some View {
        Button(action: {
            Task {
                let result = await mailboxManager.claimAll()
                if result.failed > 0 {
                    capacityAlertMessage = mailboxManager.errorMessage ?? "部分物品因背包容量不足无法领取"
                    showCapacityAlert = true
                }
            }
        }) {
            HStack {
                if mailboxManager.isClaiming {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.to.line")
                }
                Text(mailboxManager.isClaiming ? "领取中..." : "全部领取")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(mailboxManager.pendingItems.isEmpty || mailboxManager.isClaiming
                          ? Color.gray : ApocalypseTheme.primary)
            )
        }
        .disabled(mailboxManager.pendingItems.isEmpty || mailboxManager.isClaiming)
    }

    // MARK: - 领取逻辑

    private func claimSingleItem(_ item: PendingItem) async {
        let success = await mailboxManager.claimItem(item, quantity: item.quantity)
        if !success, let error = mailboxManager.errorMessage {
            capacityAlertMessage = error
            showCapacityAlert = true
            mailboxManager.clearMessages()
        }
    }
}
