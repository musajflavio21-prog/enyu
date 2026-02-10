//
//  CoinBalanceView.swift
//  EarthLord
//
//  末日币余额显示组件
//

import SwiftUI

/// 末日币余额显示
struct CoinBalanceView: View {
    @StateObject private var storeManager = StoreManager.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bitcoinsign.circle.fill")
                .foregroundColor(ApocalypseTheme.warning)
                .font(.system(size: 16))

            Text("\(storeManager.coinBalance)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(ApocalypseTheme.warning)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(ApocalypseTheme.warning.opacity(0.15))
        .cornerRadius(12)
    }
}

/// 紧凑版末日币余额
struct CoinBalanceCompactView: View {
    let balance: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bitcoinsign.circle.fill")
                .foregroundColor(ApocalypseTheme.warning)
                .font(.system(size: 12))

            Text("\(balance)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(ApocalypseTheme.warning)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CoinBalanceView()
        CoinBalanceCompactView(balance: 360)
    }
    .padding()
    .background(Color.black)
}
