//
//  BuildingLocationPickerView.swift
//  EarthLord
//
//  地图位置选择器
//  用于在领地内选择建筑放置位置
//

import SwiftUI
import MapKit
import CoreLocation

/// 地图位置选择器视图
struct BuildingLocationPickerView: View {

    // MARK: - 属性

    /// 领地数据
    let territory: Territory

    /// 建筑模板
    let template: BuildingTemplate

    /// 选择完成回调
    var onConfirm: ((CLLocationCoordinate2D) -> Void)?

    /// 取消回调
    var onCancel: (() -> Void)?

    // MARK: - 状态

    /// 选中的位置
    @State private var selectedLocation: CLLocationCoordinate2D?

    /// 是否位置有效（在领地内）
    @State private var isValidLocation = false

    /// 提示消息
    @State private var hintMessage = "点击地图选择建筑位置"

    /// 环境变量
    @Environment(\.dismiss) private var dismiss

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 地图视图
                LocationPickerMapView(
                    territory: territory,
                    selectedLocation: $selectedLocation,
                    onTap: { coordinate in
                        handleLocationTap(coordinate)
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                // 顶部提示
                VStack {
                    // 提示卡片
                    HStack(spacing: 12) {
                        Image(systemName: isValidLocation ? "checkmark.circle.fill" : "info.circle.fill")
                            .foregroundColor(isValidLocation ? .green : .orange)

                        Text(hintMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)

                        Spacer()
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .padding()

                    Spacer()

                    // 底部按钮
                    HStack(spacing: 16) {
                        // 取消按钮
                        Button(action: {
                            onCancel?()
                            dismiss()
                        }) {
                            Text("取消")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        // 确认按钮
                        Button(action: {
                            if let location = selectedLocation, isValidLocation {
                                onConfirm?(location)
                                dismiss()
                            }
                        }) {
                            Text("确认位置")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isValidLocation ? Color.green : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(!isValidLocation)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                }
            }
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel?()
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - 辅助方法

    /// 处理位置点击
    private func handleLocationTap(_ coordinate: CLLocationCoordinate2D) {
        selectedLocation = coordinate

        // 检查是否在领地内（点击坐标是 GCJ-02，需用 GCJ-02 多边形检查）
        let rawPolygon = territory.toCoordinates()
        let gcj02Polygon = CoordinateConverter.convertCoordinates(rawPolygon)
        let isInside = TerritoryManager.shared.isPointInPolygon(point: coordinate, polygon: gcj02Polygon)

        if isInside {
            isValidLocation = true
            hintMessage = "位置有效，点击「确认位置」完成"
        } else {
            isValidLocation = false
            hintMessage = "位置无效：必须在领地范围内"
        }
    }
}

// MARK: - 地图选择器视图

/// 位置选择地图视图
struct LocationPickerMapView: UIViewRepresentable {
    let territory: Territory
    @Binding var selectedLocation: CLLocationCoordinate2D?
    var onTap: ((CLLocationCoordinate2D) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = .standard

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 移除旧的覆盖层和标注
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

        // 获取领地坐标（WGS-84 -> GCJ-02 转换）
        let rawCoordinates = territory.toCoordinates()
        guard rawCoordinates.count >= 3 else { return }
        let coordinates = CoordinateConverter.convertCoordinates(rawCoordinates)

        // 添加领地多边形
        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polygon)

        // 添加选中位置标注
        if let location = selectedLocation {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location
            annotation.title = "建筑位置"
            mapView.addAnnotation(annotation)
        }

        // 设置地图区域
        if context.coordinator.isFirstUpdate {
            setInitialRegion(mapView: mapView, coordinates: coordinates)
            context.coordinator.isFirstUpdate = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func setInitialRegion(mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }

        let centerLat = (latitudes.min()! + latitudes.max()!) / 2
        let centerLon = (longitudes.min()! + longitudes.max()!) / 2
        let latDelta = max((latitudes.max()! - latitudes.min()!) * 1.5, 0.005)
        let lonDelta = max((longitudes.max()! - longitudes.min()!) * 1.5, 0.005)

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
        mapView.setRegion(region, animated: false)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationPickerMapView
        var isFirstUpdate = true

        init(_ parent: LocationPickerMapView) {
            self.parent = parent
        }

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

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "SelectedLocation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                view?.annotation = annotation
            }

            view?.markerTintColor = .systemGreen
            view?.glyphImage = UIImage(systemName: "mappin")
            view?.animatesWhenAdded = true

            return view
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onTap?(coordinate)
        }
    }
}

// MARK: - 预览

#Preview {
    BuildingLocationPickerView(
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
        ),
        template: BuildingTemplate(
            id: "campfire",
            name: "篝火",
            description: "基础生存设施",
            category: .survival,
            tier: 1,
            maxLevel: 3,
            buildTimeSeconds: 30,
            requiredResources: ["wood": 30],
            maxPerTerritory: 2,
            iconName: "flame.fill",
            effect: nil
        )
    )
}
