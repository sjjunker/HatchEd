//
//  Resources.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import SwiftUI

struct Resources: View {
    var body: some View {
        VStack {
            Text("Resources")
                .font(.largeTitle)
                .padding()
            
            Text("Educational resources will appear here")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
    }
}

