//
//  DistanceFilterTestView.swift
//  EarthLord
//
//  距离过滤测试视图（Day 35-C）
//

#if DEBUG
import SwiftUI
import CoreLocation

struct DistanceFilterTestView: View {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var communicationManager = CommunicationManager.shared

    var body: some View {
        List {
            // 当前位置信息
            Section("当前位置") {
                if let location = locationManager.effectiveLocation {
                    Text("纬度: \(location.latitude, specifier: "%.4f")")
                    Text("经度: \(location.longitude, specifier: "%.4f")")
                    if locationManager.mockLocationEnabled {
                        Label("模拟位置已启用", systemImage: "location.fill")
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("未获取位置")
                        .foregroundColor(.secondary)
                }
            }

            // 模拟位置预设
            Section("模拟位置") {
                ForEach(LocationManager.MockLocationPreset.allCases, id: \.self) { preset in
                    Button(preset.rawValue) {
                        locationManager.setMockLocation(preset)
                    }
                }

                Button("清除模拟位置", role: .destructive) {
                    locationManager.clearMockLocation()
                }
            }

            // 当前设备
            Section("当前设备") {
                if let device = communicationManager.currentDevice {
                    Text("类型: \(device.deviceType.displayName)")
                    Text("范围: \(device.deviceType.rangeText)")
                } else {
                    Text("未选择设备")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ApocalypseTheme.background)
        .navigationTitle("距离过滤测试")
    }
}

#Preview {
    NavigationStack {
        DistanceFilterTestView()
    }
}
#endif
