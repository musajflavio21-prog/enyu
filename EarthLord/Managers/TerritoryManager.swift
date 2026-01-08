//
//  TerritoryManager.swift
//  EarthLord
//
//  领地管理器
//  负责领地数据的上传和拉取
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 领地管理器
@MainActor
class TerritoryManager: ObservableObject {

    // MARK: - 单例

    static let shared = TerritoryManager()

    // MARK: - 发布属性

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 所有领地数据
    @Published var territories: [Territory] = []

    // MARK: - 私有属性

    /// Supabase 客户端
    private let supabase: SupabaseClient

    // MARK: - 初始化

    private init() {
        // 初始化 Supabase 客户端（与 AuthManager 使用相同配置）
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://ikpvcdxtsghqbiszlaco.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlrcHZjZHh0c2docWJpc3psYWNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY3NTU5MDUsImV4cCI6MjA4MjMzMTkwNX0.M5tY-zyNpUjHE3p6b_QBmLgSaqCIekvC7uxHJvsIFt8",
            options: .init(
                auth: .init(
                    // 修复警告：使用新的会话发射行为
                    emitLocalSessionAsInitialSession: true
                )
            )
        )

        print("🗺️ [领地] TerritoryManager 初始化完成")
    }

    // MARK: - 坐标转换方法

    /// 将坐标数组转为 path JSON 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: [{"lat": x, "lon": y}, ...]
    private func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }
    }

    /// 将坐标数组转为 WKT (Well-Known Text) 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: WKT 格式的多边形字符串
    /// - Note: ⚠️ WKT 格式是「经度在前，纬度在后」！多边形必须闭合（首尾相同）！
    private func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        // 确保至少有 3 个点
        guard coordinates.count >= 3 else {
            print("⚠️ [领地] 坐标点不足 3 个，无法构建多边形")
            return ""
        }

        // 创建坐标对字符串（经度在前，纬度在后）
        var wktCoords: [String] = []
        for coord in coordinates {
            let coordString = "\(coord.longitude) \(coord.latitude)"
            wktCoords.append(coordString)
        }

        // 闭合多边形：确保首尾相同
        if let firstCoord = coordinates.first {
            let closingCoord = "\(firstCoord.longitude) \(firstCoord.latitude)"
            wktCoords.append(closingCoord)
        }

        // 构建 WKT 字符串
        let wktPolygon = "SRID=4326;POLYGON((\(wktCoords.joined(separator: ", "))))"

        print("🗺️ [领地] WKT 多边形: \(wktPolygon)")
        return wktPolygon
    }

    /// 计算边界框
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    private func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        print("🗺️ [领地] 边界框: lat[\(minLat), \(maxLat)], lon[\(minLon), \(maxLon)]")
        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 上传数据结构

    /// 领地上传数据结构
    private struct TerritoryUploadData: Encodable {
        let userId: String
        let path: [[String: Double]]
        let polygon: String
        let bboxMinLat: Double
        let bboxMaxLat: Double
        let bboxMinLon: Double
        let bboxMaxLon: Double
        let area: Double
        let pointCount: Int
        let startedAt: String
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case path
            case polygon
            case bboxMinLat = "bbox_min_lat"
            case bboxMaxLat = "bbox_max_lat"
            case bboxMinLon = "bbox_min_lon"
            case bboxMaxLon = "bbox_max_lon"
            case area
            case pointCount = "point_count"
            case startedAt = "started_at"
            case isActive = "is_active"
        }
    }

    // MARK: - 上传方法

    /// 上传领地到 Supabase
    /// - Parameters:
    ///   - coordinates: GPS 坐标数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 圈地开始时间
    /// - Throws: 上传失败时抛出错误
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        print("🚀 [领地] 开始上传领地...")
        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取当前用户 ID
            let session = try await supabase.auth.session
            let userId = session.user.id

            print("✅ [领地] 用户 ID: \(userId)")

            // 2. 转换坐标为 path JSON 格式
            let pathJSON = coordinatesToPathJSON(coordinates)

            // 3. 转换坐标为 WKT 格式（用于 PostGIS polygon 字段）
            let wktPolygon = coordinatesToWKT(coordinates)

            // 4. 计算边界框
            let bbox = calculateBoundingBox(coordinates)

            // 5. 构建上传数据
            let territoryData = TerritoryUploadData(
                userId: userId.uuidString,
                path: pathJSON,
                polygon: wktPolygon,
                bboxMinLat: bbox.minLat,
                bboxMaxLat: bbox.maxLat,
                bboxMinLon: bbox.minLon,
                bboxMaxLon: bbox.maxLon,
                area: area,
                pointCount: coordinates.count,
                startedAt: startTime.ISO8601Format(),
                isActive: true
            )

            print("📤 [领地] 上传数据 - 点数: \(coordinates.count), 面积: \(area)m²")

            // 6. 上传到 Supabase
            try await supabase
                .from("territories")
                .insert(territoryData)
                .execute()

            print("✅ [领地] 领地上传成功！")
            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)
            isLoading = false

        } catch {
            print("❌ [领地] 上传失败: \(error)")
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            errorMessage = "上传领地失败: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }

    // MARK: - 拉取方法

    /// 加载所有激活的领地
    /// - Returns: 领地数组
    /// - Throws: 加载失败时抛出错误
    func loadAllTerritories() async throws -> [Territory] {
        print("🔄 [领地] 开始加载领地...")
        isLoading = true
        errorMessage = nil

        do {
            // 查询 is_active = true 的领地
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            print("✅ [领地] 加载成功，共 \(response.count) 个领地")

            territories = response
            isLoading = false
            return response

        } catch {
            print("❌ [领地] 加载失败: \(error)")
            errorMessage = "加载领地失败: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }

    /// 加载我的领地
    /// - Returns: 我的领地数组
    /// - Throws: 加载失败时抛出错误
    func loadMyTerritories() async throws -> [Territory] {
        print("🔄 [领地] 开始加载我的领地...")
        isLoading = true
        errorMessage = nil

        do {
            // 获取当前用户 ID
            guard let userId = try? await supabase.auth.session.user.id else {
                throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])
            }

            // 查询我的领地（is_active = true）
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            print("✅ [领地] 加载我的领地成功，共 \(response.count) 个")

            isLoading = false
            return response

        } catch {
            print("❌ [领地] 加载我的领地失败: \(error)")
            errorMessage = "加载我的领地失败: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }

    /// 删除领地
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 是否删除成功
    func deleteTerritory(territoryId: String) async -> Bool {
        print("🗑️ [领地] 删除领地: \(territoryId)")
        isLoading = true

        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId)
                .execute()

            print("✅ [领地] 删除成功")
            TerritoryLogger.shared.log("领地已删除", type: .info)
            isLoading = false
            return true

        } catch {
            print("❌ [领地] 删除失败: \(error)")
            TerritoryLogger.shared.log("删除失败: \(error.localizedDescription)", type: .error)
            errorMessage = "删除失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - 辅助方法

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    // MARK: - 碰撞检测算法

    /// 射线法判断点是否在多边形内
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    /// 检查起始点是否在他人领地内
    func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) -> CollisionResult {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else {
            return .safe
        }

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            if isPointInPolygon(point: location, polygon: polygon) {
                TerritoryLogger.shared.log("起点碰撞：位于他人领地内", type: .error)
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "不能在他人领地内开始圈地！",
                    closestDistance: 0,
                    warningLevel: .violation
                )
            }
        }

        return .safe
    }

    /// 判断两条线段是否相交（CCW 算法）
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
    ) -> Bool {
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
                   (B.latitude - A.latitude) * (C.longitude - A.longitude)
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检查路径是否穿越他人领地边界
    func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return .safe }

        for i in 0..<(path.count - 1) {
            let pathStart = path[i]
            let pathEnd = path[i + 1]

            for territory in otherTerritories {
                let polygon = territory.toCoordinates()
                guard polygon.count >= 3 else { continue }

                // 检查与领地每条边的相交
                for j in 0..<polygon.count {
                    let boundaryStart = polygon[j]
                    let boundaryEnd = polygon[(j + 1) % polygon.count]

                    if segmentsIntersect(p1: pathStart, p2: pathEnd, p3: boundaryStart, p4: boundaryEnd) {
                        TerritoryLogger.shared.log("路径碰撞：轨迹穿越他人领地边界", type: .error)
                        return CollisionResult(
                            hasCollision: true,
                            collisionType: .pathCrossTerritory,
                            message: "轨迹不能穿越他人领地！",
                            closestDistance: 0,
                            warningLevel: .violation
                        )
                    }
                }

                // 检查路径点是否在领地内
                if isPointInPolygon(point: pathEnd, polygon: polygon) {
                    TerritoryLogger.shared.log("路径碰撞：轨迹点进入他人领地", type: .error)
                    return CollisionResult(
                        hasCollision: true,
                        collisionType: .pointInTerritory,
                        message: "轨迹不能进入他人领地！",
                        closestDistance: 0,
                        warningLevel: .violation
                    )
                }
            }
        }

        return .safe
    }

    /// 计算当前位置到他人领地的最近距离
    func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String) -> Double {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return Double.infinity }

        var minDistance = Double.infinity
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()

            for vertex in polygon {
                let vertexLocation = CLLocation(latitude: vertex.latitude, longitude: vertex.longitude)
                let distance = currentLocation.distance(from: vertexLocation)
                minDistance = min(minDistance, distance)
            }
        }

        return minDistance
    }

    /// 综合碰撞检测（主方法）
    func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 1. 检查路径是否穿越他人领地
        let crossResult = checkPathCrossTerritory(path: path, currentUserId: currentUserId)
        if crossResult.hasCollision {
            return crossResult
        }

        // 2. 计算到最近领地的距离
        guard let lastPoint = path.last else { return .safe }
        let minDistance = calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId)

        // 3. 根据距离确定预警级别和消息
        let warningLevel: WarningLevel
        let message: String?

        if minDistance > 100 {
            warningLevel = .safe
            message = nil
        } else if minDistance > 50 {
            warningLevel = .caution
            message = "注意：距离他人领地 \(Int(minDistance))m"
        } else if minDistance > 25 {
            warningLevel = .warning
            message = "警告：正在靠近他人领地（\(Int(minDistance))m）"
        } else {
            warningLevel = .danger
            message = "危险：即将进入他人领地！（\(Int(minDistance))m）"
        }

        if warningLevel != .safe {
            TerritoryLogger.shared.log("距离预警：\(warningLevel.description)，距离 \(Int(minDistance))m", type: .warning)
        }

        return CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: minDistance,
            warningLevel: warningLevel
        )
    }
}
