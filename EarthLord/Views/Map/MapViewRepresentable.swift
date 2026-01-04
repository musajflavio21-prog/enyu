//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器
//  提供末世风格的地图显示，支持用户位置追踪、自动居中和路径绘制
//

import SwiftUI
import MapKit

/// MKMapView 的 SwiftUI 包装器
/// 使用 UIViewRepresentable 将 UIKit 的 MKMapView 集成到 SwiftUI
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - 绑定属性

    /// 用户位置坐标（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @Binding var hasLocatedUser: Bool

    /// 路径坐标数组（用于绘制圈地轨迹）
    @Binding var pathCoordinates: [CLLocationCoordinate2D]

    /// 路径更新版本号（触发更新）
    @Binding var pathUpdateVersion: Int

    /// 是否正在追踪
    @Binding var isTracking: Bool

    // MARK: - 轨迹标识符

    /// 轨迹 Overlay 的标识符
    private static let trackingOverlayIdentifier = "trackingPath"

    // MARK: - UIViewRepresentable

    /// 创建 MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 配置地图类型：卫星图+道路标签（末世废土风格）
        mapView.mapType = .hybrid

        // 隐藏 POI 标签（商店、餐厅等）
        mapView.pointOfInterestFilter = .excludingAll

        // 隐藏 3D 建筑
        mapView.showsBuildings = false

        // 显示用户位置蓝点（关键！这会触发位置更新）
        mapView.showsUserLocation = true

        // 允许用户交互
        mapView.isZoomEnabled = true      // 允许缩放
        mapView.isScrollEnabled = true    // 允许拖动
        mapView.isRotateEnabled = true    // 允许旋转
        mapView.isPitchEnabled = true     // 允许倾斜

        // 显示指南针和比例尺
        mapView.showsCompass = true
        mapView.showsScale = true

        // 设置代理（关键！否则代理方法不会被调用）
        mapView.delegate = context.coordinator

        // 保存 mapView 引用到 Coordinator
        context.coordinator.mapView = mapView

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        // 设置初始区域（默认显示中国中心区域）
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
            latitudinalMeters: 5000000,
            longitudinalMeters: 5000000
        )
        mapView.setRegion(initialRegion, animated: false)

        print("🗺️ [地图] MKMapView 创建完成")
        return mapView
    }

    /// 更新 MKMapView（SwiftUI 状态变化时调用）
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新路径轨迹
        context.coordinator.updateTrackingPath(coordinates: pathCoordinates, on: mapView)
    }

    /// 创建协调器
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 末世滤镜效果

    /// 应用末世风格滤镜
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度
        guard let colorControls = CIFilter(name: "CIColorControls") else { return }
        colorControls.setValue(-0.1, forKey: kCIInputBrightnessKey)   // 稍微变暗
        colorControls.setValue(0.6, forKey: kCIInputSaturationKey)    // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        guard let sepiaFilter = CIFilter(name: "CISepiaTone") else { return }
        sepiaFilter.setValue(0.5, forKey: kCIInputIntensityKey)       // 泛黄强度

        // 应用滤镜到地图图层
        mapView.layer.filters = [colorControls, sepiaFilter]

        print("🗺️ [地图] 末世滤镜已应用")
    }

    // MARK: - Coordinator（地图代理）

    /// 协调器类
    /// 处理 MKMapView 的代理回调和轨迹绘制
    class Coordinator: NSObject, MKMapViewDelegate {

        /// 父视图引用
        var parent: MapViewRepresentable

        /// MapView 引用
        weak var mapView: MKMapView?

        /// 是否已完成首次居中（防止重复居中）
        private var hasInitialCentered = false

        /// 当前轨迹 Overlay
        private var currentTrackingOverlay: MKPolyline?

        /// 上次更新的坐标数量（用于判断是否需要更新）
        private var lastCoordinateCount = 0

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
            super.init()
        }

        // MARK: - 轨迹绘制

        /// 更新追踪路径
        /// - Parameters:
        ///   - coordinates: 路径坐标数组
        ///   - mapView: 地图视图
        func updateTrackingPath(coordinates: [CLLocationCoordinate2D], on mapView: MKMapView) {
            // 检查是否需要更新
            guard coordinates.count != lastCoordinateCount || coordinates.count < 2 else {
                return
            }

            lastCoordinateCount = coordinates.count

            // 移除旧的轨迹
            if let oldOverlay = currentTrackingOverlay {
                mapView.removeOverlay(oldOverlay)
                currentTrackingOverlay = nil
            }

            // 如果坐标少于2个点，不绘制
            guard coordinates.count >= 2 else {
                print("📍 [轨迹] 坐标点不足，跳过绘制")
                return
            }

            // 转换坐标（WGS-84 -> GCJ-02）
            let convertedCoordinates = CoordinateConverter.convertCoordinates(coordinates)

            // 创建新的轨迹线
            let polyline = MKPolyline(coordinates: convertedCoordinates, count: convertedCoordinates.count)
            polyline.title = MapViewRepresentable.trackingOverlayIdentifier

            // 添加到地图
            mapView.addOverlay(polyline)
            currentTrackingOverlay = polyline

            print("📍 [轨迹] 更新轨迹，共 \(coordinates.count) 个点")
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 关键方法：渲染 Overlay（轨迹线）
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 末世风格轨迹样式
                renderer.strokeColor = UIColor(ApocalypseTheme.primary).withAlphaComponent(0.9)
                renderer.lineWidth = 5.0
                renderer.lineCap = .round
                renderer.lineJoin = .round

                // 添加发光效果（通过阴影模拟）
                renderer.alpha = 1.0

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        /// ⭐ 关键方法：用户位置更新时调用
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else {
                print("⚠️ [地图] 用户位置为空")
                return
            }

            let coordinate = location.coordinate
            print("🗺️ [地图] 用户位置更新: (\(coordinate.latitude), \(coordinate.longitude))")

            // 更新绑定的位置
            DispatchQueue.main.async {
                self.parent.userLocation = coordinate
            }

            // 首次获得位置时，自动居中地图
            guard !hasInitialCentered else {
                return
            }

            print("🗺️ [地图] 首次定位，自动居中到用户位置")

            // 创建居中区域（约1公里范围）
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            // 平滑居中地图
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        /// 地图区域变化回调
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let center = mapView.region.center
            print("🗺️ [地图] 区域变化: (\(center.latitude), \(center.longitude))")
        }

        /// 地图加载完成回调
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("🗺️ [地图] 地图加载完成")
        }

        /// 地图加载失败回调
        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            print("❌ [地图] 地图加载失败: \(error.localizedDescription)")
        }

        /// 用户位置追踪失败回调
        func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
            print("❌ [地图] 用户位置追踪失败: \(error.localizedDescription)")
        }

        // MARK: - 辅助方法

        /// 重置首次居中标志（允许重新居中）
        func resetInitialCentered() {
            hasInitialCentered = false
        }

        /// 居中到指定位置
        func centerToLocation(_ coordinate: CLLocationCoordinate2D, animated: Bool = true) {
            guard let mapView = mapView else { return }

            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
            mapView.setRegion(region, animated: animated)
        }
    }
}

// MARK: - 预览

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        pathCoordinates: .constant([]),
        pathUpdateVersion: .constant(0),
        isTracking: .constant(false)
    )
}
