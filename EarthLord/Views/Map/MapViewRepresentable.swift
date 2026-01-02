//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器
//  提供末世风格的地图显示，支持用户位置追踪和自动居中
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

        // 设置代理（关键！否则 didUpdate userLocation 不会被调用）
        mapView.delegate = context.coordinator

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
        // 大部分更新由 Coordinator 处理
        // 这里保持空实现，避免不必要的更新
    }

    /// 创建协调器
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 末世滤镜效果

    /// 应用末世风格滤镜
    /// - 降低饱和度：让颜色更加暗淡
    /// - 棕褐色调：添加废土泛黄效果
    /// - 降低亮度：整体变暗
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
    /// 处理 MKMapView 的代理回调
    class Coordinator: NSObject, MKMapViewDelegate {

        /// 父视图引用
        var parent: MapViewRepresentable

        /// 是否已完成首次居中（防止重复居中）
        private var hasInitialCentered = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
            super.init()
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 关键方法：用户位置更新时调用
        /// 这是地图自动居中的核心实现
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
                // 已经居中过了，不再自动居中（避免干扰用户手动拖动）
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
            // 可以在这里处理地图缩放/拖动后的逻辑
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
    }
}

// MARK: - 预览

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false)
    )
}
