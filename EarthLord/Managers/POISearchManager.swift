//
//  POISearchManager.swift
//  EarthLord
//
//  POI 搜索管理器
//  使用 MapKit 搜索附近真实地点，用于探索时搜刮
//

import Foundation
import MapKit
import CoreLocation

// Note: RealPOI and POIType are defined in MockExplorationData.swift

/// POI 搜索管理器
/// 负责使用 MapKit 的 MKLocalSearch 搜索附近真实地点
class POISearchManager {

    // MARK: - 单例

    static let shared = POISearchManager()

    private init() {}

    // MARK: - 搜索配置

    /// 搜索关键词配置（中文 + 英文）
    private let searchTerms: [(term: String, type: POIType)] = [
        ("超市", .supermarket),
        ("便利店", .supermarket),
        ("医院", .hospital),
        ("诊所", .hospital),
        ("药店", .pharmacy),
        ("加油站", .gasStation),
        ("餐厅", .supermarket),
        ("咖啡店", .supermarket)
    ]

    /// 最大POI数量（iOS地理围栏限制20个，预留5个）
    private let maxPOICount = 15

    // MARK: - 公开方法

    /// 搜索附近POI（主方法）
    /// - Parameters:
    ///   - center: 搜索中心点坐标
    ///   - radius: 搜索半径（默认1000米）
    ///   - limit: 限制返回数量（根据玩家密度动态调整，默认使用maxPOICount）
    ///   - completion: 完成回调，返回POI列表
    func searchNearbyPOIs(
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance = 1000,
        limit: Int? = nil,
        completion: @escaping ([RealPOI]) -> Void
    ) {
        print("🔍 [POI搜索] 开始搜索 中心: (\(String(format: "%.4f", center.latitude)), \(String(format: "%.4f", center.longitude))), 半径: \(radius)m")

        // 使用 Task 进行异步搜索
        Task {
            do {
                let pois = try await searchAllTypes(center: center, radius: radius, limit: limit)

                // 回到主线程回调
                await MainActor.run {
                    completion(pois)
                }
            } catch {
                print("❌ [POI搜索] 搜索失败: \(error.localizedDescription)")

                // 出错时返回空数组
                await MainActor.run {
                    completion([])
                }
            }
        }
    }

    // MARK: - 私有方法

    /// 搜索所有类型的POI（并发）
    private func searchAllTypes(
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        limit: Int? = nil
    ) async throws -> [RealPOI] {

        // 并发搜索所有类型
        let results = try await withThrowingTaskGroup(of: [MKMapItem].self) { group in
            for (term, _) in searchTerms {
                group.addTask {
                    try await self.searchPOIType(
                        center: center,
                        radius: radius,
                        searchTerm: term
                    )
                }
            }

            // 收集所有结果
            var allResults: [MKMapItem] = []
            for try await items in group {
                allResults.append(contentsOf: items)
            }
            return allResults
        }

        print("🔍 [POI搜索] MapKit 返回 \(results.count) 个原始结果")

        // 转换为 RealPOI 并去重
        let pois = convertAndDeduplicate(mapItems: results, center: center)

        print("🔍 [POI搜索] 去重后得到 \(pois.count) 个POI")

        // 限制数量（使用传入的limit或默认maxPOICount）
        let effectiveLimit = limit ?? maxPOICount
        let finalPOIs = Array(pois.prefix(effectiveLimit))

        print("✅ [POI搜索] 最终返回 \(finalPOIs.count) 个POI（限制: \(effectiveLimit)）")

        return finalPOIs
    }

    /// 搜索单一类型的POI
    private func searchPOIType(
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        searchTerm: String
    ) async throws -> [MKMapItem] {

        // 创建搜索请求
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchTerm

        // 设置搜索区域（2倍半径留余量）
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )

        // 执行搜索
        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        print("🔍 [POI搜索] 关键词 '\(searchTerm)' 找到 \(response.mapItems.count) 个结果")

        // 过滤：只保留在指定半径内的结果
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let filteredItems = response.mapItems.filter { item in
            guard let itemLocation = item.placemark.location else { return false }
            let distance = itemLocation.distance(from: centerLocation)
            return distance <= radius
        }

        print("🔍 [POI搜索] 关键词 '\(searchTerm)' 半径内有 \(filteredItems.count) 个结果")

        return filteredItems
    }

    /// 转换MapItem为RealPOI并去重
    private func convertAndDeduplicate(
        mapItems: [MKMapItem],
        center: CLLocationCoordinate2D
    ) -> [RealPOI] {

        var poisDict: [String: RealPOI] = [:]
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        for item in mapItems {
            guard let placemark = item.placemark.location else { continue }
            guard let name = item.name, !name.isEmpty else { continue }

            let coordinate = placemark.coordinate

            // 生成唯一ID（基于坐标，保留4位小数）
            let id = String(format: "%.4f_%.4f", coordinate.latitude, coordinate.longitude)

            // 去重：如果已存在，跳过
            if poisDict[id] != nil {
                continue
            }

            // 根据名称和MapKit分类映射POI类型
            let type = mapPOIType(item: item)

            let poi = RealPOI(
                id: id,
                name: name,
                type: type,
                coordinate: coordinate,
                hasBeenScavenged: false
            )

            poisDict[id] = poi
        }

        // 按距离排序（近的在前）
        let sortedPOIs = poisDict.values.sorted { poi1, poi2 in
            let loc1 = CLLocation(latitude: poi1.coordinate.latitude, longitude: poi1.coordinate.longitude)
            let loc2 = CLLocation(latitude: poi2.coordinate.latitude, longitude: poi2.coordinate.longitude)
            let dist1 = loc1.distance(from: centerLocation)
            let dist2 = loc2.distance(from: centerLocation)
            return dist1 < dist2
        }

        return sortedPOIs
    }

    /// 映射MapKit POI到游戏POI类型
    private func mapPOIType(item: MKMapItem) -> POIType {
        let name = item.name?.lowercased() ?? ""
        let category = item.pointOfInterestCategory

        // 优先根据名称关键词匹配
        if name.contains("医院") || name.contains("hospital") || name.contains("诊所") || name.contains("clinic") {
            return .hospital
        }
        if name.contains("药店") || name.contains("pharmacy") || name.contains("药房") {
            return .pharmacy
        }
        if name.contains("加油") || name.contains("gas") || name.contains("petrol") || name.contains("station") {
            return .gasStation
        }
        if name.contains("超市") || name.contains("supermarket") || name.contains("便利") || name.contains("convenience") {
            return .supermarket
        }

        // 根据 MapKit 分类匹配
        if let category = category {
            switch category {
            case .hospital:
                return .hospital
            case .pharmacy:
                return .pharmacy
            case .gasStation:
                return .gasStation
            case .store, .foodMarket:
                return .supermarket
            case .restaurant, .cafe:
                return .supermarket  // 餐厅和咖啡店也可能有食物
            default:
                break
            }
        }

        // 默认返回超市类型
        return .supermarket
    }
}
