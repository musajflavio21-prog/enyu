//
//  CreateTradeOfferView.swift
//  EarthLord
//
//  发布交易挂单页面
//  让用户选择要出的物品和想要的物品
//

import SwiftUI

/// 发布交易挂单视图
struct CreateTradeOfferView: View {

    // MARK: - 环境和状态

    @Environment(\.dismiss) private var dismiss

    @StateObject private var tradeManager = TradeManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 我要出的物品列表
    @State private var offeringItems: [TradeItem] = []

    /// 我想要的物品列表
    @State private var requestingItems: [TradeItem] = []

    /// 有效期（小时）
    @State private var expiresInHours: Int = 24

    /// 留言
    @State private var message: String = ""

    /// 是否显示物品选择器
    @State private var showItemPicker = false

    /// 物品选择器模式
    @State private var itemPickerMode: ItemPickerMode = .fromInventory

    /// 是否正在提交
    @State private var isSubmitting = false

    /// 错误提示
    @State private var errorMessage: String?
    @State private var showError = false

    /// 成功提示
    @State private var showSuccess = false

    /// 有效期选项
    private let expiresOptions = [1, 6, 12, 24, 48, 72]

    /// 是否可以发布
    private var canSubmit: Bool {
        !offeringItems.isEmpty && !requestingItems.isEmpty && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 我要出的物品
                        offeringSection

                        // 交换箭头
                        exchangeArrow

                        // 我想要的物品
                        requestingSection

                        // 有效期选择
                        expiresSection

                        // 留言
                        messageSection

                        // 发布按钮
                        submitButton
                    }
                    .padding(16)
                }
            }
            .navigationTitle("发布交易挂单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showItemPicker) {
                ItemPickerView(
                    mode: itemPickerMode,
                    inventoryItems: inventoryManager.items,
                    definitions: inventoryManager.itemDefinitions,
                    isPresented: $showItemPicker,
                    excludeItemIds: itemPickerMode == .fromInventory
                        ? offeringItems.map { $0.itemId }
                        : requestingItems.map { $0.itemId },
                    onSelect: handleItemSelected
                )
            }
            .alert("错误", isPresented: $showError) {
                Button("确定") { }
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .alert("发布成功", isPresented: $showSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("挂单已发布，物品已从背包扣除")
            }
        }
    }

    // MARK: - 我要出的物品

    private var offeringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(ApocalypseTheme.danger)
                Text("我要出的物品")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 物品列表
            VStack(spacing: 8) {
                ForEach(offeringItems.indices, id: \.self) { index in
                    let item = offeringItems[index]
                    let maxQty = inventoryManager.getAvailableQuantity(itemId: item.itemId)

                    TradeItemRow(
                        itemId: item.itemId,
                        quantity: item.quantity,
                        definitions: inventoryManager.itemDefinitions,
                        showQuantityEditor: true,
                        maxQuantity: maxQty + item.quantity, // 加回已选的数量
                        onQuantityChange: { newQty in
                            offeringItems[index] = TradeItem(itemId: item.itemId, quantity: newQty)
                        },
                        onRemove: {
                            offeringItems.remove(at: index)
                        }
                    )
                }

                // 添加按钮
                Button(action: {
                    itemPickerMode = .fromInventory
                    showItemPicker = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("添加物品")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.primary.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - 交换箭头

    private var exchangeArrow: some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(width: 44, height: 44)

                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            Spacer()
        }
    }

    // MARK: - 我想要的物品

    private var requestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(ApocalypseTheme.success)
                Text("我想要的物品")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 物品列表
            VStack(spacing: 8) {
                ForEach(requestingItems.indices, id: \.self) { index in
                    let item = requestingItems[index]

                    TradeItemRow(
                        itemId: item.itemId,
                        quantity: item.quantity,
                        definitions: inventoryManager.itemDefinitions,
                        showQuantityEditor: true,
                        maxQuantity: nil, // 无限制
                        onQuantityChange: { newQty in
                            requestingItems[index] = TradeItem(itemId: item.itemId, quantity: newQty)
                        },
                        onRemove: {
                            requestingItems.remove(at: index)
                        }
                    )
                }

                // 添加按钮
                Button(action: {
                    itemPickerMode = .fromAll
                    showItemPicker = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("添加物品")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.primary.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - 有效期选择

    private var expiresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(ApocalypseTheme.warning)
                Text("有效期")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(expiresOptions, id: \.self) { hours in
                        Button(action: {
                            expiresInHours = hours
                        }) {
                            Text(formatHours(hours))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(expiresInHours == hours ? .white : ApocalypseTheme.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(expiresInHours == hours ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                                .cornerRadius(20)
                        }
                    }
                }
            }
        }
    }

    /// 格式化小时
    private func formatHours(_ hours: Int) -> String {
        if hours < 24 {
            return "\(hours)小时"
        } else {
            return "\(hours / 24)天"
        }
    }

    // MARK: - 留言

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(ApocalypseTheme.info)
                Text("留言（可选）")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            TextField("添加一些说明...", text: $message, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(3...5)
                .padding(14)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
        }
    }

    // MARK: - 发布按钮

    private var submitButton: some View {
        Button(action: submitOffer) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("发布挂单")
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSubmit ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .cornerRadius(12)
        }
        .disabled(!canSubmit)
        .padding(.top, 10)
    }

    // MARK: - 处理方法

    /// 处理物品选择
    private func handleItemSelected(itemId: String, quantity: Int) {
        let newItem = TradeItem(itemId: itemId, quantity: quantity)

        switch itemPickerMode {
        case .fromInventory:
            // 检查是否已存在
            if let index = offeringItems.firstIndex(where: { $0.itemId == itemId }) {
                offeringItems[index] = TradeItem(itemId: itemId, quantity: offeringItems[index].quantity + quantity)
            } else {
                offeringItems.append(newItem)
            }

        case .fromAll:
            if let index = requestingItems.firstIndex(where: { $0.itemId == itemId }) {
                requestingItems[index] = TradeItem(itemId: itemId, quantity: requestingItems[index].quantity + quantity)
            } else {
                requestingItems.append(newItem)
            }
        }
    }

    /// 提交挂单
    private func submitOffer() {
        guard canSubmit else { return }

        isSubmitting = true

        Task {
            let result = await tradeManager.createOffer(
                offering: offeringItems,
                requesting: requestingItems,
                expiresInHours: expiresInHours,
                message: message.isEmpty ? nil : message
            )

            isSubmitting = false

            switch result {
            case .success:
                showSuccess = true

            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - 预览

#Preview {
    CreateTradeOfferView()
}
