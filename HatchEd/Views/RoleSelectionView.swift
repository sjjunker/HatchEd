//
//  RoleSelectionView.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import SwiftUI

struct RoleSelectionView: View {
    let userID: String

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome!")
                .font(.title.bold())

            Text("Who is signing in?")
                .font(.headline)

            Button("I'm a Parent") {
                print("Parent selected for userID: \(userID)")
            }
            .buttonStyle(.borderedProminent)

            Button("I'm a Student") {
                print("Student selected for userID: \(userID)")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}


