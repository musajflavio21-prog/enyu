//
//  PlayerDensityManager.swift
//  EarthLord
//
//  玩家密度管理器
//  负责位置上报和附近玩家密度查询
//

import Foundation
import CoreLocation
import Supabase

/// 玩家密度等级
enum PlayerDensityTier: String, CaseIterable {
    case solo = "solo"           // 独行者：0人
    case low = "low"             // 低密度：1-5人
    case medium = "medium"       // 中密度：6-20人
    case high = "high"           // 高密度：20人以上

    /// 建议显示的POI数量
    var recommendedPOICount: Int {
        switch self {
        case .solo: return 1
        case .low: return 3
        case .medium: return 6
        case .high: return 15
        }
    }

    /// 显示名称
    var displayName: String {
        switch self {
        case .solo: return "独行者"
        case .low: return "低密度"
        case .medium: return "中密度"
        case .high: return "高密度"
        }
    }
}

/// 玩家密度管理器
class PlayerDensityManager {

    // MARK: - 单例

    static let shared = PlayerDensityManager()

    private init() {}

    // MARK: - 配置常量

    /// 上报间隔（秒）
    private let reportInterval: TimeInterval = 30

    /// 移动距离阈值（米）
    private let movementThreshold: CLLocationDistance = 50

    /// 查询半径（米）
    private let queryRadius: Int = 1000

    // MARK: - 状态属性

    /// 定时器
    private var reportTimer: Timer?

    /// 上次上报的位置
    private var lastReportedLocation: CLLocationCoordinate2D?

    /// 上次上报的时间
    private var lastReportTime: Date?

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        AuthManager.shared.supabaseClient
    }

    // MARK: - 公开方法

    /// 开始位置上报（探索开始时调用）
    func startLocationReporting() {
        print("📡 [密度] 开始位置上报")

        // 立即上报一次
        reportCurrentLocation()

        // 启动定时器
        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            self?.reportCurrentLocation()
        }
    }

    /// 停止位置上报（探索结束时调用）
    func stopLocationReporting() {
        print("📡 [密度] 停止位置上报")
        reportTimer?.invalidate()
        reportTimer = nil
        lastReportedLocation = nil
        lastReportTime = nil
    }

    /// 检查是否需要立即上报（移动超过阈值时）
    func checkMovementReport() {
        guard let currentLocation = LocationManager.shared.userLocation else { return }
        guard let lastLocation = lastReportedLocation else {
            // 从未上报过，立即上报
            reportCurrentLocation()
            return
        }

        let distance = currentLocation.distance(from: lastLocation)
        if distance >= movementThreshold {
            print("📡 [密度] 移动超过\(movementThreshold)米，立即上报")
            reportCurrentLocation()
        }
    }

    /// 查询附近玩家数量并返回密度等级
    func queryNearbyPlayersAndDensity(completion: @escaping (Int, PlayerDensityTier) -> Void) {
        guard let currentLocation = LocationManager.shared.userLocation else {
            print("⚠️ [密度] 当前位置为空，无法查询")
            completion(0, .solo)
            return
        }

        print("🔍 [密度] 查询附近\(queryRadius)米内的玩家...")

        Task {
            do {
                let count: Int = try await supabase.rpc(
                    "count_nearby_players",
                    params: [
                        "p_latitude": currentLocation.latitude,
                        "p_longitude": currentLocation.longitude,
                        "p_radius_meters": Double(queryRadius)
                    ]
                ).execute().value

                let tier = calculateDensityTier(playerCount: count)

                await MainActor.run {
                    print("🎯 [密度] 查询结果: \(count)人，密度等级: \(tier.displayName)")
                    completion(count, tier)
                }
            } catch {
                print("❌ [密度] 查询失败: \(error.localizedDescription)")
                await MainActor.run {
                    // 查询失败时，默认为独行者模式，只显示1个POI
                    completion(0, .solo)
                }
            }
        }
    }

    // MARK: - 私有方法

    /// 上报当前位置
    private func reportCurrentLocation() {
        guard let currentLocation = LocationManager.shared.userLocation else {
            print("⚠️ [密度] 当前位置为空，跳过上报")
            return
        }

        print("📍 [密度] 上报位置: (\(String(format: "%.6f", currentLocation.latitude)), \(String(format: "%.6f", currentLocation.longitude)))")

        Task {
            do {
                try await supabase.rpc(
                    "upsert_player_location",
                    params: [
                        "p_latitude": currentLocation.latitude,
                        "p_longitude": currentLocation.longitude
                    ]
                ).execute()

                await MainActor.run {
                    self.lastReportedLocation = currentLocation
                    self.lastReportTime = Date()
                    print("✅ [密度] 位置上报成功")
                }
            } catch {
                print("❌ [密度] 位置上报失败: \(error.localizedDescription)")
            }
        }
    }

    /// 计算密度等级
    private func calculateDensityTier(playerCount: Int) -> PlayerDensityTier {
        switch playerCount {
        case 0:
            return .solo
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }
}

// MARK: - CLLocationCoordinate2D 扩展

extension CLLocationCoordinate2D {
    /// 计算两个坐标点之间的距离（米）
    func distance(from other: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to)
    }
}
