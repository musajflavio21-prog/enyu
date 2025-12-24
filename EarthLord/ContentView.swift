//
//  ContentView.swift
//  EarthLord
//
//  Created by Zhuanz密码0000 on 2025/12/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")

                Text("Developed by enyu")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)

                NavigationLink(destination: TestView()) {
                    Text("进入测试页")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
