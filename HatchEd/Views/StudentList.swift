//
//  StudentList.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import SwiftUI

struct StudentList: View {
    var body: some View {
        VStack {
            Text("Student List")
                .font(.largeTitle)
                .padding()
            
            Text("Your students will appear here")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Students")
        .navigationBarTitleDisplayMode(.inline)
    }
}

