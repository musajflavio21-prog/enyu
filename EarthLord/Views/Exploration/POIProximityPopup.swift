//
//  POIProximityPopup.swift
//  EarthLord
//
//  POI 接近弹窗
//  玩家走到 POI 50米范围内时显示的搜刮提示
//

import SwiftUI

struct POIProximityPopup: View {
    let poi: RealPOI
    let onScavenge: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // POI信息
            VStack(spacing: 12) {
                // 类型图标
                ZStack {
                    Circle()
                        .fill(typeColor.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: typeIcon)
                        .font(.system(size: 40))
                        .foregroundColor(typeColor)
                }

                Text("发现废墟")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text(poi.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(poi.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)

            Divider()

            // 按钮组
            HStack(spacing: 16) {
                Button(action: onDismiss) {
                    Text("稍后再说")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                Button(action: onScavenge) {
                    Text("立即搜刮")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding(24)
        .presentationDetents([.height(350)])
    }

    private var typeColor: Color {
        switch poi.type {
        case .supermarket: return .green
        case .hospital: return .red
        case .pharmacy: return .purple
        case .gasStation: return .orange
        default: return .blue
        }
    }

    private var typeIcon: String {
        poi.type.iconName
    }
}
