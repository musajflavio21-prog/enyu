//
//  TestView.swift
//  EarthLord
//
//  Created by enyu on 2025/12/24.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            Color(.systemBlue)
                .opacity(0.3)
                .ignoresSafeArea()

            Text("这里是分支宇宙的测试页")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    TestView()
}
