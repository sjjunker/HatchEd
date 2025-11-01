//
//  Portfolio.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import SwiftUI

struct Portfolio: View {
    var body: some View {
        VStack {
            Text("Portfolio")
                .font(.largeTitle)
                .padding()
            
            Text("Student portfolios will appear here")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.inline)
    }
}

