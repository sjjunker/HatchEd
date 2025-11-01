//
//  RoleSelectionView.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import SwiftUI

struct RoleSelectionView: View {
    let userID: String
    @EnvironmentObject var signInManager: AppleSignInManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome!")
                .font(.title.bold())

            Text("Who is signing in?")
                .font(.headline)

            Button("I'm a Parent") {
                signInManager.saveRole("parent")
            }
            .buttonStyle(.borderedProminent)

            Button("I'm a Student") {
                signInManager.saveRole("student")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}


