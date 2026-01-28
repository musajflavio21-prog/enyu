//
//  BuildingManager.swift
//  EarthLord
//
//  建筑管理器
//  负责建筑模板加载、建造检查、建造流程和升级
//

import Foundation
import Combine
import Supabase

/// 建筑管理器
@MainActor
class BuildingManager: ObservableObject {

    // MARK: - 单例

    static let shared = BuildingManager()

    // MARK: - 发布属性

    /// 建筑模板列表
    @Published var templates: [BuildingTemplate] = []

    /// 玩家建筑列表（当前领地）
    @Published var playerBuildings: [PlayerBuilding] = []

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        AuthManager.shared.supabaseClient
    }

    /// 建造完成检查定时器
    private var constructionTimer: Timer?

    // MARK: - 初始化

    private init() {
        print("🏗️ [BuildingManager] 初始化")
        loadTemplates()
    }

    // MARK: - 模板加载

    /// 从 JSON 文件加载建筑模板
    func loadTemplates() {
        print("🏗️ [BuildingManager] 开始加载建筑模板...")

        // 调试：列出 Bundle 中所有 json 文件
        if let resourcePath = Bundle.main.resourcePath {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                let jsonFiles = files.filter { $0.hasSuffix(".json") }
                print("🏗️ [BuildingManager] Bundle 中的 JSON 文件: \(jsonFiles)")
            } catch {
                print("🏗️ [BuildingManager] 无法列出 Bundle 文件: \(error)")
            }
        }

        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("❌ [BuildingManager] 找不到 building_templates.json 文件")
            print("❌ [BuildingManager] Bundle 路径: \(Bundle.main.bundlePath)")
            errorMessage = "找不到建筑模板文件"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            // 注意：不使用 .convertFromSnakeCase，因为 BuildingTemplate 已有自定义 CodingKeys
            let file = try decoder.decode(BuildingTemplatesFile.self, from: data)
            templates = file.templates
            print("🏗️ [BuildingManager] ✅ 成功加载 \(templates.count) 个建筑模板")
        } catch {
            print("❌ [BuildingManager] 加载建筑模板失败: \(error)")
            errorMessage = "加载建筑模板失败: \(error.localizedDescription)"
        }
    }

    /// 根据 ID 获取建筑模板
    func getTemplate(byId templateId: String) -> BuildingTemplate? {
        return templates.first { $0.id == templateId }
    }

    /// 根据分类获取建筑模板
    func getTemplates(byCategory category: BuildingCategory) -> [BuildingTemplate] {
        return templates.filter { $0.category == category }
    }

    // MARK: - 建造检查

    /// 检查是否可以建造
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地 ID
    ///   - playerResources: 玩家资源（itemId -> 数量）
    /// - Returns: Result<Void, BuildingError>
    func canBuild(
        template: BuildingTemplate,
        territoryId: String,
        playerResources: [String: Int]
    ) -> Result<Void, BuildingError> {
        // 1. 检查资源是否足够
        for (resourceId, requiredAmount) in template.requiredResources {
            let currentAmount = playerResources[resourceId] ?? 0
            if currentAmount < requiredAmount {
                print("🏗️ [BuildingManager] 资源不足: \(resourceId) 需要 \(requiredAmount), 当前 \(currentAmount)")
                return .failure(.insufficientResources)
            }
        }

        // 2. 检查该领地该类型建筑是否达到上限
        let existingCount = playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == template.id
        }.count

        if existingCount >= template.maxPerTerritory {
            print("🏗️ [BuildingManager] 建筑数量已达上限: \(template.name) 最多 \(template.maxPerTerritory) 个")
            return .failure(.maxBuildingsReached)
        }

        return .success(())
    }

    /// 检查玩家资源（从 InventoryManager 获取）
    func getPlayerResources() -> [String: Int] {
        let inventory = InventoryManager.shared
        var resources: [String: Int] = [:]

        for item in inventory.items {
            resources[item.itemId] = (resources[item.itemId] ?? 0) + item.quantity
        }

        return resources
    }

    // MARK: - 建造流程

    /// 开始建造
    /// - Parameters:
    ///   - templateId: 建筑模板 ID
    ///   - territoryId: 领地 ID
    ///   - location: 建筑位置（可选）
    /// - Returns: 新建建筑记录或错误
    func startConstruction(
        templateId: String,
        territoryId: String,
        location: (lat: Double, lon: Double)? = nil
    ) async -> Result<PlayerBuilding, BuildingError> {
        // 1. 检查登录状态
        guard let userId = AuthManager.shared.currentUser?.id else {
            return .failure(.notLoggedIn)
        }

        // 2. 获取模板
        guard let template = getTemplate(byId: templateId) else {
            return .failure(.templateNotFound)
        }

        // 3. 获取玩家资源
        let playerResources = getPlayerResources()

        // 4. 检查是否可以建造
        let checkResult = canBuild(
            template: template,
            territoryId: territoryId,
            playerResources: playerResources
        )

        if case .failure(let error) = checkResult {
            return .failure(error)
        }

        // 5. 扣除资源
        let resourceConsumed = await consumeResources(template.requiredResources)
        if !resourceConsumed {
            return .failure(.insufficientResources)
        }

        // 6. 创建建筑记录
        let newBuilding = NewPlayerBuilding(
            userId: userId.uuidString,
            territoryId: territoryId,
            templateId: templateId,
            buildingName: template.name,
            status: BuildingStatus.constructing.rawValue,
            level: 1,
            locationLat: location?.lat,
            locationLon: location?.lon,
            buildStartedAt: Date()
        )

        do {
            let insertedBuilding: PlayerBuilding = try await supabase
                .from("player_buildings")
                .insert(newBuilding)
                .select()
                .single()
                .execute()
                .value

            // 添加到本地列表
            playerBuildings.append(insertedBuilding)

            print("🏗️ [BuildingManager] ✅ 开始建造: \(template.name)")
            print("🏗️ [BuildingManager] 建造时间: \(template.buildTimeSeconds) 秒")

            // 启动建造完成检查
            startConstructionTimer()

            return .success(insertedBuilding)
        } catch {
            print("❌ [BuildingManager] 创建建筑记录失败: \(error)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }

    /// 消耗资源
    /// - Parameter resources: 需要消耗的资源 {itemId: quantity}
    /// - Returns: 是否成功
    private func consumeResources(_ resources: [String: Int]) async -> Bool {
        let inventory = InventoryManager.shared

        for (itemId, quantity) in resources {
            // 找到对应的背包物品
            guard let item = inventory.items.first(where: { $0.itemId == itemId }) else {
                print("❌ [BuildingManager] 找不到资源: \(itemId)")
                return false
            }

            // 检查数量是否足够
            if item.quantity < quantity {
                print("❌ [BuildingManager] 资源不足: \(itemId)")
                return false
            }

            // 消耗资源
            let success = await inventory.useItem(item, quantity: quantity)
            if !success {
                print("❌ [BuildingManager] 消耗资源失败: \(itemId)")
                return false
            }

            print("🏗️ [BuildingManager] 消耗资源: \(itemId) x\(quantity)")
        }

        return true
    }

    /// 完成建造
    /// - Parameter buildingId: 建筑 ID
    func completeConstruction(buildingId: UUID) async -> Result<PlayerBuilding, BuildingError> {
        // 1. 找到建筑记录
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            return .failure(.buildingNotFound)
        }

        var building = playerBuildings[index]

        // 2. 检查状态
        guard building.status == .constructing else {
            return .failure(.invalidStatus)
        }

        // 3. 更新状态
        do {
            let now = Date()
            let updateData = BuildingStatusUpdate(
                status: BuildingStatus.active.rawValue,
                buildCompletedAt: now,
                updatedAt: now
            )
            try await supabase
                .from("player_buildings")
                .update(updateData)
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 更新本地记录
            building.status = .active
            building.buildCompletedAt = now
            building.updatedAt = now
            playerBuildings[index] = building

            print("🏗️ [BuildingManager] ✅ 建造完成: \(building.buildingName)")

            return .success(building)
        } catch {
            print("❌ [BuildingManager] 完成建造失败: \(error)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }

    // MARK: - 升级

    /// 升级建筑
    /// - Parameter buildingId: 建筑 ID
    func upgradeBuilding(buildingId: UUID) async -> Result<PlayerBuilding, BuildingError> {
        // 1. 找到建筑记录
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            return .failure(.buildingNotFound)
        }

        var building = playerBuildings[index]

        // 2. 检查状态（只有运行中的建筑可以升级）
        guard building.status == .active else {
            print("🏗️ [BuildingManager] 只有运行中的建筑可以升级")
            return .failure(.invalidStatus)
        }

        // 3. 获取模板检查最大等级
        guard let template = getTemplate(byId: building.templateId) else {
            return .failure(.templateNotFound)
        }

        if building.level >= template.maxLevel {
            print("🏗️ [BuildingManager] 建筑已达最高等级: \(template.maxLevel)")
            return .failure(.invalidStatus)
        }

        // 4. 计算升级所需资源（基础资源 * 等级系数）
        let levelMultiplier = Double(building.level + 1) * 0.5
        var upgradeResources: [String: Int] = [:]
        for (resourceId, baseAmount) in template.requiredResources {
            upgradeResources[resourceId] = Int(Double(baseAmount) * levelMultiplier)
        }

        // 5. 检查并消耗资源
        let playerResources = getPlayerResources()
        for (resourceId, requiredAmount) in upgradeResources {
            let currentAmount = playerResources[resourceId] ?? 0
            if currentAmount < requiredAmount {
                print("🏗️ [BuildingManager] 升级资源不足: \(resourceId)")
                return .failure(.insufficientResources)
            }
        }

        let resourceConsumed = await consumeResources(upgradeResources)
        if !resourceConsumed {
            return .failure(.insufficientResources)
        }

        // 6. 更新等级
        do {
            let newLevel = building.level + 1
            let now = Date()
            let updateData = BuildingLevelUpdate(
                level: newLevel,
                updatedAt: now
            )
            try await supabase
                .from("player_buildings")
                .update(updateData)
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 更新本地记录
            building.level = newLevel
            building.updatedAt = now
            playerBuildings[index] = building

            print("🏗️ [BuildingManager] ✅ 建筑升级: \(building.buildingName) -> Lv.\(newLevel)")

            return .success(building)
        } catch {
            print("❌ [BuildingManager] 升级建筑失败: \(error)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }

    /// 计算升级所需资源
    func getUpgradeCost(for building: PlayerBuilding) -> [String: Int]? {
        guard let template = getTemplate(byId: building.templateId) else {
            return nil
        }

        if building.level >= template.maxLevel {
            return nil
        }

        let levelMultiplier = Double(building.level + 1) * 0.5
        var upgradeResources: [String: Int] = [:]
        for (resourceId, baseAmount) in template.requiredResources {
            upgradeResources[resourceId] = Int(Double(baseAmount) * levelMultiplier)
        }

        return upgradeResources
    }

    // MARK: - 数据加载

    /// 加载玩家在某领地的建筑
    /// - Parameter territoryId: 领地 ID
    func fetchPlayerBuildings(territoryId: String) async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "请先登录"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let buildings: [PlayerBuilding] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("territory_id", value: territoryId)
                .order("created_at", ascending: false)
                .execute()
                .value

            playerBuildings = buildings
            print("🏗️ [BuildingManager] 加载了 \(buildings.count) 个建筑")

            // 检查是否有需要完成的建造
            await checkConstructionProgress()
        } catch {
            print("❌ [BuildingManager] 加载建筑失败: \(error)")
            errorMessage = "加载建筑失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 加载玩家所有建筑
    func fetchAllPlayerBuildings() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            errorMessage = "请先登录"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let buildings: [PlayerBuilding] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            playerBuildings = buildings
            print("🏗️ [BuildingManager] 加载了 \(buildings.count) 个建筑（全部领地）")

            // 检查是否有需要完成的建造
            await checkConstructionProgress()
        } catch {
            print("❌ [BuildingManager] 加载建筑失败: \(error)")
            errorMessage = "加载建筑失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 建造进度检查

    /// 启动建造完成检查定时器
    private func startConstructionTimer() {
        // 如果已有定时器在运行，不重复启动
        guard constructionTimer == nil else { return }

        constructionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkConstructionProgress()
            }
        }
    }

    /// 停止建造完成检查定时器
    private func stopConstructionTimer() {
        constructionTimer?.invalidate()
        constructionTimer = nil
    }

    /// 检查建造进度
    func checkConstructionProgress() async {
        var hasConstructing = false

        for building in playerBuildings where building.status == .constructing {
            hasConstructing = true

            guard let template = getTemplate(byId: building.templateId) else { continue }

            if building.isConstructionComplete(template: template) {
                // 自动完成建造
                let _ = await completeConstruction(buildingId: building.id)
            }
        }

        // 如果没有建造中的建筑，停止定时器
        if !hasConstructing {
            stopConstructionTimer()
        }
    }

    // MARK: - 删除

    /// 删除建筑
    /// - Parameter buildingId: 建筑 ID
    func deleteBuilding(buildingId: UUID) async -> Result<Void, BuildingError> {
        do {
            try await supabase
                .from("player_buildings")
                .delete()
                .eq("id", value: buildingId.uuidString)
                .execute()

            playerBuildings.removeAll { $0.id == buildingId }
            print("🏗️ [BuildingManager] 删除建筑: \(buildingId)")

            return .success(())
        } catch {
            print("❌ [BuildingManager] 删除建筑失败: \(error)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }

    // MARK: - 辅助方法

    /// 获取某领地的建筑数量（按模板统计）
    func getBuildingCount(templateId: String, territoryId: String) -> Int {
        return playerBuildings.filter {
            $0.templateId == templateId && $0.territoryId == territoryId
        }.count
    }

    /// 获取某分类的所有建筑
    func getBuildings(byCategory category: BuildingCategory) -> [PlayerBuilding] {
        return playerBuildings.filter { building in
            guard let template = getTemplate(byId: building.templateId) else { return false }
            return template.category == category
        }
    }

    /// 清除错误
    func clearError() {
        errorMessage = nil
    }
}
