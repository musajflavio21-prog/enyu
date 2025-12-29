//
//  MoreTabView.swift
//  EarthLord
//
//  Created by enyu on 2025/12/24.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            List {
                // Supabase Test Section
                Section {
                    NavigationLink {
                        SupabaseTestView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Supabase 连接测试")
                                    .font(.body)
                                Text("检测后端服务连接状态")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("开发工具")
                }

                // Future sections placeholder
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .frame(width: 32)

                        Text("设置")
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                    .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .frame(width: 32)

                        Text("关于")
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                    .foregroundColor(.secondary)
                } header: {
                    Text("其他")
                }
            }
            .navigationTitle("更多")
        }
    }
}

#Preview {
    MoreTabView()
}
