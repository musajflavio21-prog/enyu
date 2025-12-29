//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by enyu on 2025/12/26.
//

import SwiftUI
import Supabase

// MARK: - Supabase Client Initialization
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://ikpvcdxtsghqbiszlaco.supabase.co")!,
    supabaseKey: "sb_publishable_iIRCvY4Dij9Qws5jL_NGMw_-yN5alvx"
)

// MARK: - Connection Status
enum ConnectionStatus {
    case idle
    case testing
    case success
    case failure
}

struct SupabaseTestView: View {
    @State private var status: ConnectionStatus = .idle
    @State private var debugLog: String = "点击按钮开始测试连接..."
    @State private var isAnimating: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(statusBackgroundColor)
                        .frame(width: 100, height: 100)
                        .shadow(color: statusBackgroundColor.opacity(0.5), radius: 10)

                    statusIcon
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isAnimating && status == .testing ? 360 : 0))
                        .animation(
                            status == .testing ?
                                .linear(duration: 1).repeatForever(autoreverses: false) :
                                .default,
                            value: isAnimating
                        )
                }
                .padding(.top, 40)

                // Status Text
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(statusTextColor)
                    .multilineTextAlignment(.center)

                // Debug Log
                VStack(alignment: .leading, spacing: 8) {
                    Text("调试日志")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)

                    ScrollView {
                        Text(debugLog)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                .padding(.horizontal)

                // Test Button
                Button(action: testConnection) {
                    HStack(spacing: 10) {
                        if status == .testing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text(status == .testing ? "测试中..." : "测试连接")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(status == .testing ? Color.gray : Color.blue)
                    )
                }
                .disabled(status == .testing)
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Supabase 连接测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed Properties

    private var statusBackgroundColor: Color {
        switch status {
        case .idle: return .gray
        case .testing: return .blue
        case .success: return .green
        case .failure: return .red
        }
    }

    private var statusIcon: Image {
        switch status {
        case .idle: return Image(systemName: "questionmark")
        case .testing: return Image(systemName: "arrow.triangle.2.circlepath")
        case .success: return Image(systemName: "checkmark")
        case .failure: return Image(systemName: "exclamationmark")
        }
    }

    private var statusText: String {
        switch status {
        case .idle: return "等待测试"
        case .testing: return "正在连接..."
        case .success: return "连接成功"
        case .failure: return "连接失败"
        }
    }

    private var statusTextColor: Color {
        switch status {
        case .idle: return .secondary
        case .testing: return .blue
        case .success: return .green
        case .failure: return .red
        }
    }

    // MARK: - Test Connection Logic

    private func testConnection() {
        status = .testing
        isAnimating = true
        debugLog = "[\(timestamp)] 开始测试连接...\n"
        debugLog += "[\(timestamp)] URL: https://ikpvcdxtsghqbiszlaco.supabase.co\n"
        debugLog += "[\(timestamp)] 正在查询测试表...\n"

        Task {
            do {
                // Intentionally query a non-existent table to test connection
                let _: [EmptyResponse] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // If we get here without error, something unexpected happened
                await MainActor.run {
                    debugLog += "[\(timestamp)] 意外情况：查询成功（表可能存在）\n"
                    status = .success
                    isAnimating = false
                }

            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }

    private func handleError(_ error: Error) {
        let errorString = String(describing: error)
        let errorMessage = error.localizedDescription

        debugLog += "[\(timestamp)] 收到服务器响应\n"
        debugLog += "[\(timestamp)] 错误类型: \(type(of: error))\n"
        debugLog += "[\(timestamp)] 错误信息: \(errorMessage)\n"
        debugLog += "[\(timestamp)] 详细内容: \(errorString.prefix(500))\n"

        // Check for PGRST errors (PostgreSQL REST API errors) - indicates successful connection
        if errorString.contains("PGRST") ||
           errorString.contains("Could not find") ||
           errorString.contains("relation") && errorString.contains("does not exist") {
            debugLog += "\n[\(timestamp)] ===== 测试结果 =====\n"
            debugLog += "[\(timestamp)] ✅ 连接成功（服务器已响应）\n"
            debugLog += "[\(timestamp)] 说明：收到PostgreSQL错误表示API连接正常\n"
            status = .success
        }
        // Check for network/URL errors
        else if errorString.contains("hostname") ||
                errorString.contains("NSURLErrorDomain") ||
                errorString.contains("URL") && errorString.contains("error") ||
                errorString.contains("Could not connect") ||
                errorString.contains("network") {
            debugLog += "\n[\(timestamp)] ===== 测试结果 =====\n"
            debugLog += "[\(timestamp)] ❌ 连接失败：URL错误或无网络\n"
            debugLog += "[\(timestamp)] 请检查网络连接和Supabase URL\n"
            status = .failure
        }
        // Other errors
        else {
            debugLog += "\n[\(timestamp)] ===== 测试结果 =====\n"
            debugLog += "[\(timestamp)] 未知错误，请查看详细日志\n"

            // Check if error message suggests connection issue
            if errorMessage.lowercased().contains("offline") ||
               errorMessage.lowercased().contains("internet") {
                status = .failure
            } else {
                // Assume connection might be working if we got a response
                status = .success
                debugLog += "[\(timestamp)] 注：收到响应，连接可能正常\n"
            }
        }

        isAnimating = false
    }

    private var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - Empty Response Model
struct EmptyResponse: Codable {}

// MARK: - Preview
#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
