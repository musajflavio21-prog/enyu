//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI物品生成器
//  Day23: 调用Edge Function生成独特的物品和背景故事
//

import Foundation
import Supabase

/// AI生成的物品
struct AIGeneratedItem: Codable {
    let name: String         // AI生成的独特名称
    let category: String     // 医疗/食物/工具/武器/材料
    let rarity: String       // common/uncommon/rare/epic/legendary
    let story: String        // 背景故事
}

/// Edge Function 请求结构
struct GenerateItemsRequest: Codable {
    let poi: POIInfo
    let itemCount: Int
}

struct POIInfo: Codable {
    let name: String
    let type: String
    let dangerLevel: Int
}

/// Edge Function 响应结构
struct GenerateItemsResponse: Codable {
    let success: Bool
    let items: [AIGeneratedItem]?
    let error: String?
}

/// AI物品生成器
@MainActor
class AIItemGenerator {

    static let shared = AIItemGenerator()

    private init() {}

    private var supabase: SupabaseClient {
        AuthManager.shared.supabaseClient
    }

    /// 为POI生成AI物品
    /// - Parameters:
    ///   - poi: 真实POI对象
    ///   - dangerLevel: 危险值（根据POI类型映射）
    ///   - count: 物品数量
    /// - Returns: AI生成的物品列表，失败返回nil
    func generateItems(for poi: RealPOI, dangerLevel: Int, count: Int) async -> [AIGeneratedItem]? {
        print("🤖 [AI生成] 开始为POI生成物品: \(poi.name), 危险值: \(dangerLevel), 数量: \(count)")

        let request = GenerateItemsRequest(
            poi: POIInfo(
                name: poi.name,
                type: poi.type.rawValue,
                dangerLevel: dangerLevel
            ),
            itemCount: count
        )

        do {
            // 调用Edge Function（SDK会自动解码JSON响应）
            let response: GenerateItemsResponse = try await supabase.functions.invoke(
                "generate-ai-item",
                options: FunctionInvokeOptions(body: request)
            )

            if response.success, let items = response.items {
                print("✅ [AI生成] 成功生成 \(items.count) 件物品")
                for item in items {
                    print("  - \(item.name) [\(item.rarity)]")
                }
                return items
            } else {
                print("❌ [AI生成] 失败: \(response.error ?? "未知错误")")
                return nil
            }
        } catch {
            print("❌ [AI生成] 调用失败: \(error.localizedDescription)")
            return nil
        }
    }
}
