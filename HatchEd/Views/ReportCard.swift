//
//  ReportCard.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import SwiftUI

struct ReportCard: View {
    var body: some View {
        VStack {
            Text("Report Cards")
                .font(.largeTitle)
                .padding()
            
            Text("Student report cards will appear here")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Report Cards")
        .navigationBarTitleDisplayMode(.inline)
    }
}

