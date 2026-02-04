//
//  PTTCallView.swift
//  EarthLord
//
//  呼叫中心页面（PTT 按键通话）
//  Day 36 实现
//

import SwiftUI

struct PTTCallView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var isPTTPressed = false
    @State private var showCallsignSettings = false
    @State private var pttScale: CGFloat = 1.0

    private var currentDevice: CommunicationDevice? {
        communicationManager.currentDevice
    }

    private var canTransmit: Bool {
        currentDevice?.deviceType.canSend ?? false
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            headerView

            Spacer()

            // 呼号卡片
            callsignCard

            Spacer()

            // PTT 按钮
            pttButton

            Spacer()

            // 设备状态栏
            deviceStatusBar

            // 呼号设置入口
            callsignSettingsButton
        }
        .padding()
        .background(ApocalypseTheme.background)
        .task {
            if let userId = authManager.currentUserId {
                await communicationManager.loadUserCallsign(userId: userId)
            }
        }
        .sheet(isPresented: $showCallsignSettings) {
            CallsignSettingsSheet()
                .environmentObject(authManager)
        }
    }

    // MARK: - 头部视图

    private var headerView: some View {
        HStack {
            Text("PTT 呼叫")
                .font(.title2).fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 信号强度指示
            HStack(spacing: 2) {
                ForEach(0..<4) { i in
                    Rectangle()
                        .fill(i < signalStrength ? ApocalypseTheme.success : ApocalypseTheme.textSecondary.opacity(0.3))
                        .frame(width: 4, height: CGFloat(6 + i * 3))
                        .cornerRadius(1)
                }
            }
        }
    }

    private var signalStrength: Int {
        switch currentDevice?.deviceType {
        case .satellite: return 4
        case .campRadio: return 3
        case .walkieTalkie: return 2
        case .radio: return 1
        default: return 0
        }
    }

    // MARK: - 呼号卡片

    private var callsignCard: some View {
        VStack(spacing: 16) {
            // 呼号标签
            Text("我的呼号")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 呼号显示
            Text(communicationManager.getCurrentCallsign())
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(ApocalypseTheme.primary)

            // 设备信息
            if let device = currentDevice {
                HStack(spacing: 8) {
                    Image(systemName: device.deviceType.iconName)
                        .font(.caption)
                    Text(device.deviceType.displayName)
                        .font(.caption)
                    Text("·")
                        .font(.caption)
                    Text("覆盖 \(device.deviceType.rangeText)")
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - PTT 按钮

    private var pttButton: some View {
        VStack(spacing: 16) {
            // PTT 圆形按钮
            ZStack {
                // 外圈动画
                Circle()
                    .stroke(isPTTPressed ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3), lineWidth: 3)
                    .frame(width: 160, height: 160)
                    .scaleEffect(isPTTPressed ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isPTTPressed)

                // 按钮本体
                Circle()
                    .fill(
                        canTransmit
                            ? (isPTTPressed ? ApocalypseTheme.primary : ApocalypseTheme.primary.opacity(0.8))
                            : ApocalypseTheme.textSecondary.opacity(0.3)
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(pttScale)

                // 图标
                VStack(spacing: 8) {
                    Image(systemName: isPTTPressed ? "waveform" : "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)

                    Text(isPTTPressed ? "正在发送..." : "按住说话")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if canTransmit && !isPTTPressed {
                            isPTTPressed = true
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                pttScale = 0.95
                            }
                            // 触发震动
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        if isPTTPressed {
                            isPTTPressed = false
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                pttScale = 1.0
                            }
                        }
                    }
            )
            .disabled(!canTransmit)

            // 提示文字
            if !canTransmit {
                Text("当前设备无法发送")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.warning)
            }
        }
    }

    // MARK: - 设备状态栏

    private var deviceStatusBar: some View {
        HStack(spacing: 16) {
            // 当前设备
            VStack(spacing: 4) {
                Image(systemName: currentDevice?.deviceType.iconName ?? "antenna.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
                Text(currentDevice?.deviceType.displayName ?? "无设备")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)

            // 通讯范围
            VStack(spacing: 4) {
                Text(currentDevice?.deviceType.rangeText ?? "-")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("通讯范围")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)

            // 发送能力
            VStack(spacing: 4) {
                Image(systemName: canTransmit ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(canTransmit ? ApocalypseTheme.success : ApocalypseTheme.warning)
                Text(canTransmit ? "可发送" : "仅接收")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 呼号设置入口

    private var callsignSettingsButton: some View {
        Button {
            showCallsignSettings = true
        } label: {
            HStack {
                Image(systemName: "person.text.rectangle")
                    .font(.body)
                Text("设置呼号")
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundColor(ApocalypseTheme.textPrimary)
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
        .padding(.top, 8)
    }
}

#Preview {
    PTTCallView()
        .environmentObject(AuthManager.shared)
}
