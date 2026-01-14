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

    /// 路径是否已闭环
    @Binding var isPathClosed: Bool

    /// 已加载的领地列表
    var territories: [Territory]

    /// 当前用户 ID
    var currentUserId: String?

    /// 附近 POI 列表（Day22 搜刮系统）
    @Binding var nearbyPOIs: [RealPOI]

    // MARK: - Overlay 标识符

    /// 轨迹线 Overlay 的标识符
    private static let trackingOverlayIdentifier = "trackingPath"

    /// 闭环多边形 Overlay 的标识符
    private static let closedPolygonIdentifier = "closedPolygon"

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
        // 更新路径轨迹（传递闭环状态）
        context.coordinator.updateTrackingPath(
            coordinates: pathCoordinates,
            isPathClosed: isPathClosed,
            on: mapView
        )

        // 绘制领地
        context.coordinator.drawTerritories(
            territories: territories,
            currentUserId: currentUserId,
            on: mapView
        )

        // 更新 POI 标记（Day22 搜刮系统）
        context.coordinator.updatePOIAnnotations(
            pois: nearbyPOIs,
            on: mapView
        )
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

        /// 当前轨迹线 Overlay
        private var currentTrackingOverlay: MKPolyline?

        /// 当前闭环多边形 Overlay
        private var currentPolygonOverlay: MKPolygon?

        /// 上次更新的坐标数量（用于判断是否需要更新）
        private var lastCoordinateCount = 0

        /// 上次的闭环状态
        private var lastClosedState = false

        /// 上次加载的领地数量
        private var lastTerritoryCount = 0

        /// 上次加载的 POI 数量（Day22）
        private var lastPOICount = 0

        /// 当前的 POI Annotations（Day22）
        private var currentPOIAnnotations: [POIAnnotation] = []

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
            super.init()
        }

        // MARK: - 轨迹绘制

        /// 更新追踪路径
        /// - Parameters:
        ///   - coordinates: 路径坐标数组
        ///   - isPathClosed: 路径是否闭环
        ///   - mapView: 地图视图
        func updateTrackingPath(coordinates: [CLLocationCoordinate2D], isPathClosed: Bool, on mapView: MKMapView) {
            // 检查是否需要更新（坐标数量变化或闭环状态变化）
            let needsUpdate = coordinates.count != lastCoordinateCount || isPathClosed != lastClosedState

            guard needsUpdate || coordinates.count < 2 else {
                return
            }

            lastCoordinateCount = coordinates.count
            lastClosedState = isPathClosed

            // 移除旧的轨迹线
            if let oldOverlay = currentTrackingOverlay {
                mapView.removeOverlay(oldOverlay)
                currentTrackingOverlay = nil
            }

            // 移除旧的多边形
            if let oldPolygon = currentPolygonOverlay {
                mapView.removeOverlay(oldPolygon)
                currentPolygonOverlay = nil
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
            // 用标题标识闭环状态
            polyline.title = isPathClosed ? "closedPath" : MapViewRepresentable.trackingOverlayIdentifier

            // 添加轨迹线到地图
            mapView.addOverlay(polyline)
            currentTrackingOverlay = polyline

            // 如果闭环，添加填充多边形
            if isPathClosed && coordinates.count >= 3 {
                let polygon = MKPolygon(coordinates: convertedCoordinates, count: convertedCoordinates.count)
                polygon.title = MapViewRepresentable.closedPolygonIdentifier

                // 多边形在轨迹线下方
                mapView.insertOverlay(polygon, below: polyline)
                currentPolygonOverlay = polygon

                print("✅ [轨迹] 路径闭环！添加填充多边形")
            }

            print("📍 [轨迹] 更新轨迹，共 \(coordinates.count) 个点，闭环: \(isPathClosed)")
        }

        // MARK: - 领地绘制

        /// 绘制领地多边形
        /// - Parameters:
        ///   - territories: 领地列表
        ///   - currentUserId: 当前用户 ID
        ///   - mapView: 地图视图
        func drawTerritories(territories: [Territory], currentUserId: String?, on mapView: MKMapView) {
            // 检查是否需要更新
            guard territories.count != lastTerritoryCount else {
                return
            }

            lastTerritoryCount = territories.count

            // 移除旧的领地多边形（保留路径轨迹）
            let territoryOverlays = mapView.overlays.filter { overlay in
                if let polygon = overlay as? MKPolygon {
                    return polygon.title == "mine" || polygon.title == "others"
                }
                return false
            }
            mapView.removeOverlays(territoryOverlays)

            print("🗺️ [领地] 开始绘制 \(territories.count) 个领地")

            // 绘制每个领地
            for territory in territories {
                var coords = territory.toCoordinates()

                // ⚠️ 中国大陆需要坐标转换（WGS-84 -> GCJ-02）
                coords = coords.map { coord in
                    CoordinateConverter.wgs84ToGcj02(coord)
                }

                guard coords.count >= 3 else {
                    print("⚠️ [领地] 领地 \(territory.id) 坐标点不足，跳过")
                    continue
                }

                let polygon = MKPolygon(coordinates: coords, count: coords.count)

                // ⚠️ 关键：比较 userId 时必须统一大小写！
                // 数据库存的是小写 UUID，但 iOS 的 uuidString 返回大写
                // 如果不转换，会导致自己的领地显示为橙色
                let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
                polygon.title = isMine ? "mine" : "others"

                mapView.addOverlay(polygon, level: .aboveRoads)

                print("🗺️ [领地] 添加领地 \(territory.id)，颜色: \(isMine ? "绿色(我的)" : "橙色(他人)")")
            }

            print("✅ [领地] 领地绘制完成")
        }

        // MARK: - POI 标记管理（Day22）

        /// 更新 POI 标记
        /// - Parameters:
        ///   - pois: POI 列表
        ///   - mapView: 地图视图
        func updatePOIAnnotations(pois: [RealPOI], on mapView: MKMapView) {
            // 检查是否需要更新
            guard pois.count != lastPOICount else {
                return
            }

            lastPOICount = pois.count

            // 移除旧的 POI Annotations
            mapView.removeAnnotations(currentPOIAnnotations)
            currentPOIAnnotations.removeAll()

            print("🗺️ [POI] 开始绘制 \(pois.count) 个POI标记")

            // 添加新的 POI Annotations
            for poi in pois {
                let annotation = POIAnnotation(poi: poi)
                mapView.addAnnotation(annotation)
                currentPOIAnnotations.append(annotation)

                print("🗺️ [POI] 添加标记: \(poi.name) (\(poi.type.displayName))")
            }

            print("✅ [POI] POI标记绘制完成")
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 关键方法：渲染 Overlay（轨迹线和多边形）
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 渲染轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 根据闭环状态设置颜色
                if polyline.title == "closedPath" {
                    // 闭环后：绿色轨迹
                    renderer.strokeColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 0.95)
                } else {
                    // 追踪中：青色轨迹（原设计为橙色，改为青色以便与绿色区分）
                    renderer.strokeColor = UIColor(red: 0.0, green: 0.8, blue: 0.9, alpha: 0.9)
                }

                renderer.lineWidth = 5.0
                renderer.lineCap = .round
                renderer.lineJoin = .round
                renderer.alpha = 1.0

                return renderer
            }

            // 渲染多边形（闭环路径或领地）
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 根据多边形类型设置样式
                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 2.0
                } else if polygon.title == "others" {
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                    renderer.lineWidth = 2.0
                } else {
                    // 闭环路径：绿色（默认）
                    renderer.fillColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 0.25)
                    renderer.strokeColor = .clear  // 边框由轨迹线绘制
                    renderer.lineWidth = 0
                }

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        /// ⭐ 关键方法：渲染 Annotation（POI 标记）
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置蓝点使用默认渲染
            if annotation is MKUserLocation {
                return nil
            }

            // POI 标记
            guard let poiAnnotation = annotation as? POIAnnotation else {
                return nil
            }

            let identifier = "POIAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            // 根据 POI 类型和搜刮状态设置图标
            let poi = poiAnnotation.poi
            let iconName = poi.type.iconName
            let baseColor = typeColor(for: poi.type)

            // 如果已搜刮，显示灰色；否则显示彩色
            let color = poi.hasBeenScavenged ? UIColor.gray : baseColor

            // 创建自定义图标（增大尺寸，更明显）
            let size = CGSize(width: 44, height: 44)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                let ctx = context.cgContext

                // 绘制外圈白色边框（增强可见性）
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fillEllipse(in: CGRect(origin: .zero, size: size))

                // 绘制圆形背景（更鲜艳）
                color.withAlphaComponent(0.85).setFill()
                let innerCircle = CGRect(x: 3, y: 3, width: 38, height: 38)
                let circlePath = UIBezierPath(ovalIn: innerCircle)
                circlePath.fill()

                // 绘制SF Symbol图标（增大尺寸）
                let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
                if let symbolImage = UIImage(systemName: iconName, withConfiguration: symbolConfig) {
                    UIColor.white.setFill()  // 图标使用白色，对比更强
                    let imageRect = CGRect(x: 11, y: 11, width: 22, height: 22)
                    symbolImage.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: imageRect)
                }
            }

            annotationView?.image = image

            // 添加阴影效果，使标记更突出
            annotationView?.layer.shadowColor = UIColor.black.cgColor
            annotationView?.layer.shadowOffset = CGSize(width: 0, height: 2)
            annotationView?.layer.shadowRadius = 4
            annotationView?.layer.shadowOpacity = 0.5

            return annotationView
        }

        /// 获取 POI 类型对应的颜色
        private func typeColor(for type: POIType) -> UIColor {
            switch type {
            case .supermarket: return .systemGreen
            case .hospital: return .systemRed
            case .pharmacy: return .systemPurple
            case .gasStation: return .systemOrange
            default: return .systemBlue
            }
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
        isTracking: .constant(false),
        isPathClosed: .constant(false),
        territories: [],
        currentUserId: nil,
        nearbyPOIs: .constant([])
    )
}
