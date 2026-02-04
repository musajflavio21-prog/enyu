//
//  CallsignSettingsSheet.swift
//  EarthLord
//
//  呼号设置弹窗
//  Day 36 实现
//

import SwiftUI

struct CallsignSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var callsignInput = ""
    @State private var isSaving = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?

    private var isValidCallsign: Bool {
        let trimmed = callsignInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 16
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 说明
                VStack(spacing: 8) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("设置你的呼号")
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("呼号是你在无线电通讯中的代号\n其他幸存者将通过呼号识别你")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // 当前呼号
                if let currentCallsign = communicationManager.userCallsign {
                    VStack(spacing: 4) {
                        Text("当前呼号")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(currentCallsign)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                }

                // 输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("新呼号")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    TextField("输入呼号 (2-16字符)", text: $callsignInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)

                    HStack {
                        Text("建议使用英文字母和数字组合")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Spacer()

                        Text("\(callsignInput.count)/16")
                            .font(.caption)
                            .foregroundColor(
                                callsignInput.count > 16
                                    ? .red
                                    : ApocalypseTheme.textSecondary
                            )
                    }
                }

                // 错误提示
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()

                // 保存按钮
                Button {
                    Task {
                        await saveCallsign()
                    }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isSaving ? "保存中..." : "保存呼号")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidCallsign ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
                    .cornerRadius(12)
                }
                .disabled(!isValidCallsign || isSaving)
            }
            .padding()
            .background(ApocalypseTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .onAppear {
                // 预填当前呼号
                if let current = communicationManager.userCallsign {
                    callsignInput = current
                }
            }
            .alert("保存成功", isPresented: $showSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("你的呼号已更新为「\(callsignInput)」")
            }
        }
    }

    // MARK: - 方法

    private func saveCallsign() async {
        guard isValidCallsign else { return }

        isSaving = true
        errorMessage = nil

        guard let userId = authManager.currentUserId else {
            errorMessage = "未登录"
            isSaving = false
            return
        }

        let trimmedCallsign = callsignInput.trimmingCharacters(in: .whitespacesAndNewlines)

        let success = await communicationManager.updateUserCallsign(
            userId: userId,
            callsign: trimmedCallsign.isEmpty ? nil : trimmedCallsign
        )

        isSaving = false

        if success {
            showSuccessAlert = true
        } else {
            errorMessage = communicationManager.errorMessage ?? "保存失败，请重试"
        }
    }
}

#Preview {
    CallsignSettingsSheet()
        .environmentObject(AuthManager.shared)
}
