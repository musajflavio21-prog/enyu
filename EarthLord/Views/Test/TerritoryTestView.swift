//
//  TerritoryTestView.swift
//  EarthLord
//
//  圈地功能测试界面
//  显示圈地模块的运行日志，支持清空和导出
//

import SwiftUI

/// 圈地功能测试界面
/// 注意：不要套 NavigationStack，它是从 TestMenuView 导航进来的
struct TerritoryTestView: View {

    // MARK: - 环境和观察对象

    /// 定位管理器（监听追踪状态）
    @EnvironmentObject var locationManager: LocationManager

    /// 日志管理器（监听日志更新）
    @ObservedObject var logger = TerritoryLogger.shared

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 日志滚动区域
            logScrollView

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 底部按钮
            bottomButtons
                .padding(16)
        }
        .background(ApocalypseTheme.background)
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 子视图

    /// 状态指示器
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            // 状态点
            Circle()
                .fill(locationManager.isTracking ? Color.green : ApocalypseTheme.textSecondary)
                .frame(width: 10, height: 10)

            // 状态文本
            Text(locationManager.isTracking ? "追踪中" : "未追踪")
                .font(.subheadline)
                .foregroundColor(locationManager.isTracking ? Color.green : ApocalypseTheme.textSecondary)

            Spacer()

            // 日志条数
            Text("\(logger.logs.count) 条日志")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    /// 日志滚动区域
    private var logScrollView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if logger.logs.isEmpty {
                        // 空状态提示
                        emptyStateView
                    } else {
                        // 日志内容
                        ForEach(logger.logs) { entry in
                            logEntryRow(entry)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)

                // 底部锚点（用于自动滚动）
                Color.clear
                    .frame(height: 1)
                    .id("bottom")
            }
            .onChange(of: logger.logText) { _, _ in
                // 日志更新时自动滚动到底部
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollProxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无日志")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("开始圈地追踪后，日志会显示在这里")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    /// 单条日志行
    private func logEntryRow(_ entry: LogEntry) -> some View {
        let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter
        }()

        return HStack(alignment: .top, spacing: 0) {
            // 时间戳
            Text("[\(timeFormatter.string(from: entry.timestamp))]")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 日志类型
            Text(" [\(entry.type.rawValue)]")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(logTypeColor(entry.type))

            // 消息内容
            Text(" \(entry.message)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.vertical, 2)
    }

    /// 底部按钮
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            // 清空日志按钮
            Button(action: {
                logger.clear()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("清空日志")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.cardBackground)
                )
            }
            .disabled(logger.logs.isEmpty)
            .opacity(logger.logs.isEmpty ? 0.5 : 1.0)

            // 导出日志按钮
            ShareLink(item: logger.export()) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出日志")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.primary)
                )
            }
            .disabled(logger.logs.isEmpty)
            .opacity(logger.logs.isEmpty ? 0.5 : 1.0)
        }
    }

    // MARK: - 辅助方法

    /// 根据日志类型返回对应颜色
    private func logTypeColor(_ type: LogType) -> Color {
        switch type {
        case .info:
            return ApocalypseTheme.textSecondary
        case .success:
            return Color.green
        case .warning:
            return ApocalypseTheme.warning
        case .error:
            return ApocalypseTheme.danger
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LocationManager.shared)
    }
}
