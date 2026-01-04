//
//  CoordinateConverter.swift
//  EarthLord
//
//  坐标转换器
//  用于 WGS-84 (GPS) 和 GCJ-02 (中国地图) 坐标系之间的转换
//  解决中国地图偏移问题，让轨迹正确显示在道路上
//

import Foundation
import CoreLocation

/// 坐标转换器
/// GPS 使用 WGS-84 坐标系，中国地图使用 GCJ-02 坐标系
/// 如果不转换，轨迹会偏离实际道路
enum CoordinateConverter {

    // MARK: - 常量

    /// 地球半径（米）
    private static let earthRadius: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    /// 圆周率
    private static let pi: Double = 3.14159265358979324

    // MARK: - 公开方法

    /// WGS-84 转 GCJ-02
    /// - Parameter coordinate: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国地图坐标）
    static func wgs84ToGcj02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果在中国境外，不需要转换
        if isOutOfChina(coordinate) {
            return coordinate
        }

        var dLat = transformLat(coordinate.longitude - 105.0, coordinate.latitude - 35.0)
        var dLon = transformLon(coordinate.longitude - 105.0, coordinate.latitude - 35.0)

        let radLat = coordinate.latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((earthRadius * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (earthRadius / sqrtMagic * cos(radLat) * pi)

        let mgLat = coordinate.latitude + dLat
        let mgLon = coordinate.longitude + dLon

        return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
    }

    /// GCJ-02 转 WGS-84（精确逆转换）
    /// - Parameter coordinate: GCJ-02 坐标
    /// - Returns: WGS-84 坐标
    static func gcj02ToWgs84(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果在中国境外，不需要转换
        if isOutOfChina(coordinate) {
            return coordinate
        }

        // 使用迭代法进行精确逆转换
        var wgsLat = coordinate.latitude
        var wgsLon = coordinate.longitude
        var tempPoint = wgs84ToGcj02(CLLocationCoordinate2D(latitude: wgsLat, longitude: wgsLon))
        var dLat = tempPoint.latitude - coordinate.latitude
        var dLon = tempPoint.longitude - coordinate.longitude

        // 迭代收敛
        while abs(dLat) > 1e-6 || abs(dLon) > 1e-6 {
            wgsLat -= dLat
            wgsLon -= dLon
            tempPoint = wgs84ToGcj02(CLLocationCoordinate2D(latitude: wgsLat, longitude: wgsLon))
            dLat = tempPoint.latitude - coordinate.latitude
            dLon = tempPoint.longitude - coordinate.longitude
        }

        return CLLocationCoordinate2D(latitude: wgsLat, longitude: wgsLon)
    }

    /// 批量转换坐标数组 (WGS-84 -> GCJ-02)
    /// - Parameter coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func convertCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - 私有方法

    /// 判断坐标是否在中国境外
    private static func isOutOfChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        if coordinate.longitude < 72.004 || coordinate.longitude > 137.8347 {
            return true
        }
        if coordinate.latitude < 0.8293 || coordinate.latitude > 55.8271 {
            return true
        }
        return false
    }

    /// 纬度转换
    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换
    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}

// MARK: - CLLocationCoordinate2D 扩展

extension CLLocationCoordinate2D {
    /// 转换为 GCJ-02 坐标
    var gcj02: CLLocationCoordinate2D {
        return CoordinateConverter.wgs84ToGcj02(self)
    }

    /// 从 GCJ-02 转换为 WGS-84
    var wgs84: CLLocationCoordinate2D {
        return CoordinateConverter.gcj02ToWgs84(self)
    }
}
