//
//  ScavengeManager.swift
//  EarthLord
//
//  搜刮管理器
//  负责生成搜刮POI时获得的随机物品
//

import Foundation

// Note: LootRecord, ItemQuality, and related types are defined in MockExplorationData.swift

/// 搜刮管理器
/// 负责生成搜刮POI时获得的随机物品
class ScavengeManager {

    // MARK: - 单例

    static let shared = ScavengeManager()

    private init() {}

    // MARK: - 公开方法

    /// 生成搜刮物品（Day22简化版：完全随机）
    /// - Returns: 随机生成的物品列表
    func generateLoot() -> [LootRecord] {
        // 随机1-3件物品
        let itemCount = Int.random(in: 1...3)
        var loot: [LootRecord] = []

        // 从 InventoryManager 的物品池随机选择
        let allItems = InventoryManager.shared.itemDefinitions

        guard !allItems.isEmpty else {
            print("⚠️ [搜刮] 物品池为空")
            return []
        }

        print("🎁 [搜刮] 开始生成 \(itemCount) 件物品")

        for i in 0..<itemCount {
            guard let item = allItems.randomElement() else { continue }

            // 每件物品随机1-3个
            let quantity = Int.random(in: 1...3)

            // 如果物品有品质属性，随机选择品质
            let quality: ItemQuality? = item.hasQuality ? [
                ItemQuality.fresh,
                ItemQuality.normal,
                ItemQuality.stale
            ].randomElement() : nil

            let record = LootRecord(
                id: UUID().uuidString,
                itemId: item.id,
                quantity: quantity,
                quality: quality
            )

            loot.append(record)

            print("🎁 [搜刮] 物品 \(i+1): \(item.name) x\(quantity) (品质: \(quality?.rawValue ?? "无"))")
        }

        print("✅ [搜刮] 生成完成，共 \(loot.count) 件物品")

        return loot
    }

    // MARK: - 后续扩展方向（Day22不实现）

    /*
     后续可扩展功能：
     1. 根据POI类型过滤物品池（超市→食物，医院→药品）
     2. 根据POI规模调整物品数量
     3. 添加稀有度权重（普通物品概率高，稀有物品概率低）
     4. 添加搜刮冷却机制（同一POI 4小时内不能再次搜刮）
     */
}
