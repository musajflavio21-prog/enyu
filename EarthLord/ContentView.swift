//
//  ContentView.swift
//  EarthLord
//
//  Created by Zhuanz密码0000 on 2025/12/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

            Text("Developed by enyu")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 20)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
