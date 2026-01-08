//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页
//  显示领地详细信息、地图预览、删除功能和未来功能占位
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - 属性

    /// 领地数据
    let territory: Territory

    /// 删除回调
    var onDelete: (() -> Void)?

    /// 领地管理器
    @StateObject private var territoryManager = TerritoryManager.shared

    /// 是否显示删除确认弹窗
    @State private var showDeleteAlert = false

    /// 是否正在删除
    @State private var isDeleting = false

    /// 地图区域
    @State private var mapRegion: MKCoordinateRegion

    /// 环境变量（用于关闭页面）
    @Environment(\.dismiss) private var dismiss

    // MARK: - 初始化

    init(territory: Territory, onDelete: (() -> Void)? = nil) {
        self.territory = territory
        self.onDelete = onDelete

        // 计算地图区域
        let coordinates = territory.toCoordinates()
        if let firstCoord = coordinates.first {
            // 转换为 GCJ-02（中国偏移坐标系）
            let convertedCoord = CoordinateConverter.wgs84ToGcj02(firstCoord)

            // 计算合适的缩放范围
            let latitudes = coordinates.map { $0.latitude }
            let longitudes = coordinates.map { $0.longitude }

            let minLat = latitudes.min() ?? firstCoord.latitude
            let maxLat = latitudes.max() ?? firstCoord.latitude
            let minLon = longitudes.min() ?? firstCoord.longitude
            let maxLon = longitudes.max() ?? firstCoord.longitude

            let latDelta = max((maxLat - minLat) * 1.5, 0.01)
            let lonDelta = max((maxLon - minLon) * 1.5, 0.01)

            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: convertedCoord,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            ))
        } else {
            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        }
    }

    // MARK: - 主视图

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreviewSection

                    // 基本信息
                    infoSection

                    // 未来功能占位
                    futureFeaturesSection

                    // 删除按钮
                    deleteButtonSection
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.green)
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task {
                        await deleteTerritory()
                    }
                }
            } message: {
                Text("删除后无法恢复，确认删除这个领地吗？")
            }
        }
    }

    // MARK: - 子视图

    /// 地图预览区域
    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("地图预览")
                .font(.headline)
                .foregroundColor(.white)

            Map(coordinateRegion: $mapRegion, annotationItems: [territory]) { territory in
                MapAnnotation(coordinate: mapRegion.center) {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
            .frame(height: 250)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
    }

    /// 基本信息区域
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                InfoRow(icon: "map.fill", label: "面积", value: territory.formattedArea)
                InfoRow(icon: "location.fill", label: "坐标点数", value: "\(territory.pointCount ?? 0) 个")

                if let createdAt = territory.createdAt {
                    InfoRow(icon: "calendar", label: "创建时间", value: formatDate(createdAt))
                }
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
    }

    /// 未来功能占位区域
    private var futureFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("更多功能")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                FutureFeatureRow(icon: "pencil", title: "重命名领地", subtitle: "敬请期待")
                FutureFeatureRow(icon: "building.2", title: "建筑系统", subtitle: "敬请期待")
                FutureFeatureRow(icon: "arrow.left.arrow.right", title: "领地交易", subtitle: "敬请期待")
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
    }

    /// 删除按钮区域
    private var deleteButtonSection: some View {
        Button(action: {
            showDeleteAlert = true
        }) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "trash.fill")
                    Text("删除领地")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDeleting)
    }

    // MARK: - 辅助方法

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true

        let success = await territoryManager.deleteTerritory(territoryId: territory.id)

        isDeleting = false

        if success {
            dismiss()
            onDelete?()
        }
    }

    /// 格式化日期
    private func formatDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = isoFormatter.date(from: dateString) else {
            return dateString
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")

        return formatter.string(from: date)
    }
}

// MARK: - 信息行视图

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)

            Text(label)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)

            Spacer()

            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 未来功能行视图

struct FutureFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.gray)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.6))
            }

            Spacer()
        }
    }
}

// MARK: - 预览

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "preview-id",
            userId: "user-123",
            name: "测试领地",
            path: [
                ["lat": 39.9, "lon": 116.4],
                ["lat": 39.91, "lon": 116.41],
                ["lat": 39.9, "lon": 116.41]
            ],
            area: 5000,
            pointCount: 3,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: "2025-01-07T12:00:00Z"
        )
    )
}
