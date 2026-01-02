//
//  MapTabView.swift
//  EarthLord
//
//  地图页面
//  显示末世风格地图，支持用户定位和位置追踪
//

import SwiftUI
import CoreLocation

struct MapTabView: View {

    // MARK: - 状态属性

    /// 定位管理器
    @StateObject private var locationManager = LocationManager.shared

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示坐标信息
    @State private var showCoordinateInfo = true

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 地图视图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser
            )
            .ignoresSafeArea()

            // 覆盖层
            VStack {
                // 顶部坐标信息卡片
                if showCoordinateInfo {
                    coordinateInfoCard
                        .padding(.top, 60)
                        .padding(.horizontal, 16)
                }

                Spacer()

                // 底部控制按钮
                HStack {
                    Spacer()

                    // 定位按钮
                    locationButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 120)
                }
            }

            // 权限被拒绝时的提示
            if locationManager.isDenied {
                permissionDeniedOverlay
            }
        }
        .onAppear {
            // 页面出现时检查并请求定位权限
            if locationManager.isNotDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }
        }
        .onDisappear {
            // 页面消失时停止定位（节省电量）
            // locationManager.stopUpdatingLocation()
        }
    }

    // MARK: - 子视图

    /// 坐标信息卡片
    private var coordinateInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("当前坐标")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 关闭按钮
                Button(action: {
                    withAnimation {
                        showCoordinateInfo = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 坐标值
            if let location = userLocation {
                HStack(spacing: 16) {
                    // 纬度
                    VStack(alignment: .leading, spacing: 2) {
                        Text("纬度")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(String(format: "%.6f", location.latitude))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    // 经度
                    VStack(alignment: .leading, spacing: 2) {
                        Text("经度")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(String(format: "%.6f", location.longitude))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    Spacer()
                }
            } else {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                        .scaleEffect(0.8)
                    Text("正在获取位置...")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 定位状态
            if let error = locationManager.locationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground.opacity(0.95))
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    /// 定位按钮
    private var locationButton: some View {
        Button(action: {
            // 重新定位到用户位置
            if locationManager.isAuthorized {
                hasLocatedUser = false  // 重置标志，允许重新居中
                locationManager.startUpdatingLocation()
                // 显示坐标信息
                withAnimation {
                    showCoordinateInfo = true
                }
            } else if locationManager.isDenied {
                // 打开设置
                locationManager.openSettings()
            } else {
                locationManager.requestPermission()
            }
        }) {
            ZStack {
                // 背景
                Circle()
                    .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)

                // 图标
                Image(systemName: locationManager.isAuthorized ? "location.fill" : "location.slash.fill")
                    .font(.system(size: 22))
                    .foregroundColor(locationManager.isAuthorized ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
            }
        }
    }

    /// 权限被拒绝的覆盖层
    private var permissionDeniedOverlay: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                // 图标
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 48))
                    .foregroundColor(ApocalypseTheme.warning)

                // 标题
                Text("需要定位权限")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 说明
                Text("《地球新主》需要获取您的位置来显示您在末日世界中的坐标，帮助您探索和圈定领地。")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // 前往设置按钮
                Button(action: {
                    locationManager.openSettings()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("前往设置")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ApocalypseTheme.primary)
                    )
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(ApocalypseTheme.cardBackground.opacity(0.98))
            )
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color.black.opacity(0.5))
        .ignoresSafeArea()
    }
}

// MARK: - 预览

#Preview {
    MapTabView()
}
