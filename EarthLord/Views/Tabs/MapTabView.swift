//
//  MapTabView.swift
//  EarthLord
//
//  地图页面
//  显示末世风格地图，支持用户定位、位置追踪和圈地功能
//

import SwiftUI
import CoreLocation
import Supabase

struct MapTabView: View {

    // MARK: - 状态属性

    /// 定位管理器
    @StateObject private var locationManager = LocationManager.shared

    /// 领地管理器
    @StateObject private var territoryManager = TerritoryManager.shared

    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 探索管理器
    @StateObject private var explorationManager = ExplorationManager.shared

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示坐标信息
    @State private var showCoordinateInfo = true

    /// 追踪信息刷新计时器
    @State private var trackingInfoTimer: Timer?

    /// 用于刷新追踪信息的触发器
    @State private var trackingInfoRefresh = false

    /// 是否显示速度警告
    @State private var showSpeedWarning = false

    /// 速度警告自动隐藏定时器
    @State private var speedWarningTimer: Timer?

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    /// 是否显示成功提示
    @State private var showSuccessMessage = false

    /// 成功提示消息
    @State private var successMessage = ""

    /// 是否显示错误提示
    @State private var showErrorMessage = false

    /// 错误提示消息
    @State private var errorMessage = ""

    // MARK: - Day 19: 碰撞检测状态

    /// 碰撞检测定时器
    @State private var collisionCheckTimer: Timer?

    /// 碰撞警告消息
    @State private var collisionWarning: String?

    /// 是否显示碰撞警告
    @State private var showCollisionWarning = false

    /// 碰撞警告级别
    @State private var collisionWarningLevel: WarningLevel = .safe

    // MARK: - 探索功能状态

    /// 是否显示探索结果
    @State private var showExplorationResult = false

    /// 探索结果数据
    @State private var explorationResult: ExplorationResult?

    /// 探索信息刷新触发器
    @State private var explorationInfoRefresh = false

    /// 探索信息刷新定时器
    @State private var explorationInfoTimer: Timer?

    // MARK: - Day 22: POI 搜刮状态

    /// 是否显示搜刮结果
    @State private var showScavengeResult = false

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 地图视图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                pathCoordinates: $locationManager.pathCoordinates,
                pathUpdateVersion: $locationManager.pathUpdateVersion,
                isTracking: $locationManager.isTracking,
                isPathClosed: $locationManager.isPathClosed,
                territories: territories,
                currentUserId: authManager.currentUser?.id.uuidString,
                nearbyPOIs: $explorationManager.nearbyPOIs
            )
            .ignoresSafeArea()

            // 覆盖层
            VStack {
                // 顶部信息卡片
                if explorationManager.isExploring {
                    // 探索状态栏（优先显示）
                    explorationInfoCard
                        .padding(.top, 60)
                        .padding(.horizontal, 16)
                } else if showCoordinateInfo {
                    if locationManager.isTracking {
                        trackingInfoCard
                            .padding(.top, 60)
                            .padding(.horizontal, 16)
                    } else {
                        coordinateInfoCard
                            .padding(.top, 60)
                            .padding(.horizontal, 16)
                    }
                }

                Spacer()

                // 底部控制按钮
                VStack(spacing: 16) {
                    // 「确认登记」按钮（只在验证通过时显示）
                    if locationManager.territoryValidationPassed {
                        confirmTerritoryButton
                            .padding(.horizontal, 16)
                    }

                    // 三个按钮水平分布
                    HStack(alignment: .center, spacing: 0) {
                        // 左侧：圈地按钮
                        trackingButton

                        Spacer()

                        // 中间：定位按钮
                        locationButton

                        Spacer()

                        // 右侧：探索按钮
                        exploreButton
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 120)
            }

            // 权限被拒绝时的提示
            if locationManager.isDenied {
                permissionDeniedOverlay
            }

            // 速度警告弹窗
            if showSpeedWarning, let warning = locationManager.speedWarning {
                speedWarningOverlay(message: warning)
            }

            // 验证结果横幅（根据验证结果显示成功或失败）
            if showValidationBanner {
                validationResultBanner
            }

            // 成功提示
            if showSuccessMessage {
                successMessageOverlay
            }

            // 错误提示
            if showErrorMessage {
                errorMessageOverlay
            }

            // Day 19: 碰撞警告横幅（分级颜色）
            if showCollisionWarning, let warning = collisionWarning {
                collisionWarningBanner(message: warning, level: collisionWarningLevel)
            }
        }
        .onAppear {
            // 页面出现时检查并请求定位权限
            if locationManager.isNotDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }

            // 加载领地
            Task {
                await loadTerritories()
            }
        }
        .onDisappear {
            // 页面消失时停止追踪信息刷新
            trackingInfoTimer?.invalidate()
            trackingInfoTimer = nil
        }
        .onChange(of: locationManager.isTracking) { _, isTracking in
            if isTracking {
                // 开始追踪时，启动定时器刷新追踪信息
                startTrackingInfoTimer()
            } else {
                // 停止追踪时，停止定时器
                trackingInfoTimer?.invalidate()
                trackingInfoTimer = nil
            }
        }
        .onChange(of: locationManager.speedWarning) { _, newWarning in
            if newWarning != nil {
                // 显示警告
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSpeedWarning = true
                }

                // 启动自动隐藏定时器（3秒后隐藏）
                speedWarningTimer?.invalidate()
                speedWarningTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSpeedWarning = false
                    }
                }
            }
        }
        .onChange(of: locationManager.isPathClosed) { _, isClosed in
            if isClosed {
                // 闭环后显示验证结果横幅
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showValidationBanner = true
                    }
                    // 3秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
        // Day 22: POI 接近弹窗
        .sheet(isPresented: $explorationManager.showPOIPopup) {
            if let poi = explorationManager.currentProximityPOI {
                POIProximityPopup(
                    poi: poi,
                    onScavenge: {
                        explorationManager.scavengePOI(poi)
                        showScavengeResult = true
                    },
                    onDismiss: {
                        explorationManager.showPOIPopup = false
                    }
                )
            }
        }
        // Day 22: 搜刮结果弹窗
        .sheet(isPresented: $showScavengeResult) {
            if let items = explorationManager.lastScavengedItems,
               let poiName = explorationManager.currentProximityPOI?.name {
                ScavengeResultView(
                    poiName: poiName,
                    items: items,
                    onConfirm: {
                        showScavengeResult = false
                        explorationManager.showPOIPopup = false
                    }
                )
            }
        }
    }

    // MARK: - 追踪信息刷新

    private func startTrackingInfoTimer() {
        trackingInfoTimer?.invalidate()
        trackingInfoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            trackingInfoRefresh.toggle()
        }
    }

    // MARK: - 子视图

    /// 追踪信息卡片（圈地模式）
    private var trackingInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                // 闪烁的录制指示器
                Circle()
                    .fill(ApocalypseTheme.danger)
                    .frame(width: 10, height: 10)
                    .opacity(trackingInfoRefresh ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.5), value: trackingInfoRefresh)

                Text("正在圈地")
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

            // 追踪统计
            HStack(spacing: 24) {
                // 时长
                VStack(alignment: .leading, spacing: 2) {
                    Text("时长")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(locationManager.trackingDurationString)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.primary)
                        .id(trackingInfoRefresh) // 强制刷新
                }

                // 距离
                VStack(alignment: .leading, spacing: 2) {
                    Text("距离")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(locationManager.trackingDistanceString)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                // 点数
                VStack(alignment: .leading, spacing: 2) {
                    Text("坐标点")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text("\(locationManager.pathCoordinates.count)")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }

            // 提示
            Text("走动以绘制领地边界，完成后点击结束")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ApocalypseTheme.primary.opacity(0.5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }

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

    /// 圈地按钮
    private var trackingButton: some View {
        Button(action: {
            if locationManager.isTracking {
                // 停止圈地
                stopCollisionMonitoring()
                locationManager.stopPathTracking()
            } else {
                // Day 19: 开始圈地前检测起始点
                startClaimingWithCollisionCheck()
                // 显示信息卡片
                withAnimation {
                    showCoordinateInfo = true
                }
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 14))
                Text(locationManager.isTracking ? "结束圈地" : "开始圈地")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(locationManager.isTracking ? ApocalypseTheme.danger : ApocalypseTheme.primary)
            )
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1.0 : 0.5)
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

    /// 探索按钮
    private var exploreButton: some View {
        Button(action: {
            Task {
                await toggleExploration()
            }
        }) {
            HStack(spacing: 6) {
                if explorationManager.isExploring {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14))
                    Text("结束探索")
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Image(systemName: "binoculars.fill")
                        .font(.system(size: 14))
                    Text("探索")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(explorationManager.isExploring ? ApocalypseTheme.danger : ApocalypseTheme.primary)
            )
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
        }
        .disabled(!locationManager.isAuthorized || locationManager.isTracking)
        .opacity((!locationManager.isAuthorized || locationManager.isTracking) ? 0.5 : 1.0)
        .sheet(isPresented: $showExplorationResult) {
            if let result = explorationResult {
                ExplorationResultView(explorationResult: result)
            }
        }
    }

    /// 切换探索状态
    private func toggleExploration() async {
        if explorationManager.isExploring {
            // 结束探索
            stopExplorationInfoTimer()
            if let result = await explorationManager.stopExploration() {
                explorationResult = result
                showExplorationResult = true
            }
        } else {
            // 开始探索
            await explorationManager.startExploration()
            startExplorationInfoTimer()
        }
    }

    /// 启动探索信息刷新定时器
    private func startExplorationInfoTimer() {
        explorationInfoTimer?.invalidate()
        explorationInfoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            explorationInfoRefresh.toggle()

            // 处理位置更新
            if let location = locationManager.userLocation {
                let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                Task { @MainActor in
                    explorationManager.handleLocationUpdate(clLocation)
                }
            }
        }
    }

    /// 停止探索信息刷新定时器
    private func stopExplorationInfoTimer() {
        explorationInfoTimer?.invalidate()
        explorationInfoTimer = nil
    }

    /// 探索状态信息卡片
    private var explorationInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                // 闪烁的探索指示器
                Circle()
                    .fill(ApocalypseTheme.primary)
                    .frame(width: 10, height: 10)
                    .opacity(explorationInfoRefresh ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.5), value: explorationInfoRefresh)

                Text("正在探索")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 奖励等级徽章
                HStack(spacing: 4) {
                    Image(systemName: explorationManager.currentTier.icon)
                        .font(.system(size: 12))
                    Text(explorationManager.currentTier.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(tierColor(explorationManager.currentTier))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(tierColor(explorationManager.currentTier).opacity(0.2))
                )

                // Day22+ 密度等级徽章
                HStack(spacing: 4) {
                    Image(systemName: densityIcon(explorationManager.densityTier))
                        .font(.system(size: 12))
                    Text(explorationManager.densityTier.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(densityColor(explorationManager.densityTier))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(densityColor(explorationManager.densityTier).opacity(0.2))
                )
            }

            // Day22+ 附近玩家数量提示
            if explorationManager.nearbyPlayerCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                    Text("附近有 \(explorationManager.nearbyPlayerCount) 位幸存者")
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 超速警告（如果存在）
            if explorationManager.isOverspeedWarning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("速度过快！请降低速度")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("超速 \(explorationManager.overspeedCountdown) 秒后将自动停止探索")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    // 倒计时数字
                    Text("\(explorationManager.overspeedCountdown)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .padding(12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
            }

            // 探索统计
            HStack(spacing: 24) {
                // 距离
                VStack(alignment: .leading, spacing: 2) {
                    Text("距离")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(explorationManager.formattedDistance)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.primary)
                        .id(explorationInfoRefresh)
                }

                // 时长
                VStack(alignment: .leading, spacing: 2) {
                    Text("时长")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(explorationManager.formattedDuration)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .id(explorationInfoRefresh)
                }

                // 速度
                VStack(alignment: .leading, spacing: 2) {
                    Text("速度")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(String(format: "%.1f km/h", explorationManager.currentSpeed))
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(explorationManager.isOverspeedWarning ? .red : ApocalypseTheme.textPrimary)
                        .id(explorationInfoRefresh)
                }

                Spacer()
            }

            // 提示
            Text("持续行走积累距离，距离越远奖励越好")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ApocalypseTheme.primary.opacity(0.5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    /// 获取奖励等级颜色
    private func tierColor(_ tier: RewardTier) -> Color {
        switch tier {
        case .none: return ApocalypseTheme.textSecondary
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .diamond: return Color(red: 0.0, green: 0.8, blue: 1.0)
        }
    }

    /// Day22+ 获取密度等级图标
    private func densityIcon(_ tier: PlayerDensityTier) -> String {
        switch tier {
        case .solo: return "person.fill"
        case .low: return "person.2.fill"
        case .medium: return "person.3.fill"
        case .high: return "person.3.sequence.fill"
        }
    }

    /// Day22+ 获取密度等级颜色
    private func densityColor(_ tier: PlayerDensityTier) -> Color {
        switch tier {
        case .solo: return Color.gray
        case .low: return Color.green
        case .medium: return Color.orange
        case .high: return Color.red
        }
    }

    /// 「确认登记」按钮
    private var confirmTerritoryButton: some View {
        Button(action: {
            Task {
                await uploadCurrentTerritory()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                Text("确认登记领地")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.2, green: 0.8, blue: 0.4))
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(territoryManager.isLoading)
        .opacity(territoryManager.isLoading ? 0.6 : 1.0)
    }

    /// 速度警告覆盖层
    private func speedWarningOverlay(message: String) -> some View {
        VStack {
            Spacer()
                .frame(height: 160)

            HStack(spacing: 12) {
                // 警告图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ApocalypseTheme.warning)

                // 警告信息
                VStack(alignment: .leading, spacing: 4) {
                    Text("速度警告")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 关闭按钮
                Button(action: {
                    withAnimation {
                        showSpeedWarning = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ApocalypseTheme.cardBackground.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ApocalypseTheme.warning.opacity(0.5), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        let isSuccess = locationManager.territoryValidationPassed
        let areaString = String(format: "%.1f", locationManager.calculatedArea)

        return VStack {
            Spacer()

            HStack(spacing: 12) {
                // 图标
                Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(isSuccess ? Color(red: 0.2, green: 0.8, blue: 0.4) : ApocalypseTheme.danger)

                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(isSuccess ? "领地验证成功！" : "领地验证失败")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if isSuccess {
                        Text("面积: \(areaString) m² - 点击「结束圈地」保存")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    } else if let error = locationManager.territoryValidationError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.danger.opacity(0.8))
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ApocalypseTheme.cardBackground.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                (isSuccess ? Color(red: 0.2, green: 0.8, blue: 0.4) : ApocalypseTheme.danger).opacity(0.5),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
            .padding(.bottom, 200)
        }
        .transition(.scale.combined(with: .opacity))
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

    /// 成功提示覆盖层
    private var successMessageOverlay: some View {
        VStack {
            Spacer()
                .frame(height: 160)

            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))

                Text(successMessage)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ApocalypseTheme.cardBackground.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.5), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// 错误提示覆盖层
    private var errorMessageOverlay: some View {
        VStack {
            Spacer()
                .frame(height: 160)

            HStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(ApocalypseTheme.danger)

                VStack(alignment: .leading, spacing: 4) {
                    Text("上传失败")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        showErrorMessage = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ApocalypseTheme.cardBackground.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ApocalypseTheme.danger.opacity(0.5), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - 上传方法

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // ⚠️ 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            showError("领地验证未通过，无法上传")
            return
        }

        // 确保有追踪开始时间
        guard let startTime = locationManager.trackingStartTime else {
            showError("无法获取圈地开始时间")
            return
        }

        do {
            try await territoryManager.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: startTime
            )

            showSuccess("领地登记成功！")

            // ⚠️ 关键：上传成功后必须停止追踪（会清除所有状态）
            stopCollisionMonitoring()
            locationManager.stopPathTracking()

            // 刷新领地列表，在地图上显示新领地
            await loadTerritories()

        } catch {
            showError("上传失败: \(error.localizedDescription)")
        }
    }

    /// 显示成功提示
    private func showSuccess(_ message: String) {
        successMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showSuccessMessage = true
        }

        // 3秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSuccessMessage = false
            }
        }
    }

    /// 显示错误提示
    private func showError(_ message: String) {
        errorMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showErrorMessage = true
        }

        // 5秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showErrorMessage = false
            }
        }
    }

    /// 加载所有领地
    private func loadTerritories() async {
        do {
            territories = try await territoryManager.loadAllTerritories()
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
            print("🗺️ [领地] 成功加载 \(territories.count) 个领地")
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
            print("❌ [领地] 加载失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = authManager.currentUser?.id.uuidString else {
            return
        }

        // 检测起始点是否在他人领地内
        let result = territoryManager.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = authManager.currentUser?.id.uuidString else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return VStack {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 18))

                Text(message)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor.opacity(0.95))
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 120)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
    }
}

// MARK: - 预览

#Preview {
    MapTabView()
}
