//
//  TerritoryMapView.swift
//  EarthLord
//
//  领地地图视图（UIKit MKMapView 封装）
//  显示领地边界多边形和建筑标记
//

import SwiftUI
import MapKit

/// 领地地图视图
struct TerritoryMapView: UIViewRepresentable {

    // MARK: - 属性

    /// 领地数据
    let territory: Territory

    /// 建筑列表
    var buildings: [PlayerBuilding] = []

    /// 是否允许交互
    var isInteractive: Bool = true

    /// 选中建筑回调
    var onSelectBuilding: ((PlayerBuilding) -> Void)?

    /// 地图点击回调（用于选点模式）
    var onTapLocation: ((CLLocationCoordinate2D) -> Void)?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.isUserInteractionEnabled = isInteractive
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true

        // 添加点击手势（如果需要选点）
        if onTapLocation != nil {
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
            mapView.addGestureRecognizer(tapGesture)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 移除旧的覆盖层和标注
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

        // 获取领地坐标（数据库存储 WGS-84，需转换为 GCJ-02 显示）
        let rawCoordinates = territory.toCoordinates()
        guard rawCoordinates.count >= 3 else { return }

        // WGS-84 -> GCJ-02 转换（中国地图坐标偏移修正）
        let coordinates = CoordinateConverter.convertCoordinates(rawCoordinates)

        // 添加多边形覆盖层
        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polygon)

        // 添加建筑标注
        for building in buildings {
            if let coordinate = building.coordinate {
                let annotation = BuildingAnnotation(building: building)
                annotation.coordinate = coordinate
                mapView.addAnnotation(annotation)
            }
        }

        // 设置地图区域
        setMapRegion(mapView: mapView, coordinates: coordinates)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 辅助方法

    /// 设置地图区域以显示整个领地
    private func setMapRegion(mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return }

        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }

        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2

        let latDelta = max((maxLat - minLat) * 1.5, 0.005)
        let lonDelta = max((maxLon - minLon) * 1.5, 0.005)

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )

        mapView.setRegion(region, animated: false)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TerritoryMapView

        init(_ parent: TerritoryMapView) {
            self.parent = parent
        }

        // 渲染多边形覆盖层
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.green.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.green.withAlphaComponent(0.8)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // 渲染建筑标注
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let buildingAnnotation = annotation as? BuildingAnnotation else { return nil }

            let identifier = "BuildingAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            // 根据建筑状态设置颜色
            if buildingAnnotation.building.status == .constructing {
                annotationView?.markerTintColor = .systemBlue
                annotationView?.glyphImage = UIImage(systemName: "hammer.fill")
            } else {
                annotationView?.markerTintColor = .systemGreen
                annotationView?.glyphImage = UIImage(systemName: "building.2.fill")
            }

            return annotationView
        }

        // 选中标注
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let buildingAnnotation = view.annotation as? BuildingAnnotation else { return }
            parent.onSelectBuilding?(buildingAnnotation.building)
            mapView.deselectAnnotation(view.annotation, animated: true)
        }

        // 处理地图点击
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onTapLocation?(coordinate)
        }
    }
}

// MARK: - 建筑标注

/// 建筑标注类
class BuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    @objc dynamic var coordinate: CLLocationCoordinate2D

    var title: String? {
        building.buildingName
    }

    var subtitle: String? {
        building.status == .constructing ? "建造中" : "Lv.\(building.level)"
    }

    init(building: PlayerBuilding) {
        self.building = building
        self.coordinate = building.coordinate ?? CLLocationCoordinate2D()
        super.init()
    }
}

// MARK: - 预览

#Preview {
    TerritoryMapView(
        territory: Territory(
            id: "preview",
            userId: "user",
            name: "测试领地",
            path: [
                ["lat": 39.9, "lon": 116.4],
                ["lat": 39.905, "lon": 116.4],
                ["lat": 39.905, "lon": 116.405],
                ["lat": 39.9, "lon": 116.405]
            ],
            area: 5000,
            pointCount: 4,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: nil
        )
    )
    .ignoresSafeArea()
}
