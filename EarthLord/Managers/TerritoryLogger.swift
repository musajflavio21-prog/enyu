//
//  TerritoryLogger.swift
//  EarthLord
//
//  圈地功能日志管理器
//  用于在真机测试时记录和显示圈地模块的运行日志
//

import Foundation
import Combine

/// 日志类型枚举
enum LogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
}

/// 日志条目结构
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType
}

/// 圈地日志管理器
/// 单例模式，支持 SwiftUI 数据绑定
class TerritoryLogger: ObservableObject {

    // MARK: - 单例

    static let shared = TerritoryLogger()

    // MARK: - 发布属性

    /// 日志条目数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    // MARK: - 私有属性

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    /// 时间格式化器（显示用：HH:mm:ss）
    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// 时间格式化器（导出用：yyyy-MM-dd HH:mm:ss）
    private let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // MARK: - 初始化

    private init() {
        // 私有初始化，确保单例
    }

    // MARK: - 公开方法

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型（默认为 info）
    func log(_ message: String, type: LogType = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, type: type)

        // 确保在主线程更新
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 添加新日志
            self.logs.append(entry)

            // 限制日志条数，移除最旧的
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }

            // 更新格式化文本
            self.updateLogText()

            // 同时输出到控制台（方便 Xcode 调试）
            print("📋 [圈地日志] [\(type.rawValue)] \(message)")
        }
    }

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.logText = ""
            print("📋 [圈地日志] 日志已清空")
        }
    }

    /// 导出日志为文本
    /// - Returns: 包含完整时间戳和头信息的日志文本
    func export() -> String {
        var result = """
        === 圈地功能测试日志 ===
        导出时间: \(exportFormatter.string(from: Date()))
        日志条数: \(logs.count)

        """

        for entry in logs {
            let time = exportFormatter.string(from: entry.timestamp)
            result += "[\(time)] [\(entry.type.rawValue)] \(entry.message)\n"
        }

        return result
    }

    // MARK: - 私有方法

    /// 更新格式化的日志文本
    private func updateLogText() {
        var text = ""

        for entry in logs {
            let time = displayFormatter.string(from: entry.timestamp)
            text += "[\(time)] [\(entry.type.rawValue)] \(entry.message)\n"
        }

        logText = text
    }
}
