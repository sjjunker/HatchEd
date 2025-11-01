//
//  Planner.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import SwiftUI

struct Planner: View {
    var body: some View {
        VStack {
            Text("Planner")
                .font(.largeTitle)
                .padding()
            
            Text("Your academic planner will appear here")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Planner")
        .navigationBarTitleDisplayMode(.inline)
    }
}

