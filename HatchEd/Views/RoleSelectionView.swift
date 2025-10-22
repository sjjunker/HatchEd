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
    @State private var goToHome = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome!")
                .font(.title.bold())

            Text("Who is signing in?")
                .font(.headline)

            Button("I'm a Parent") {
                signInManager.saveRole("parent")
                goToHome = true
            }
            .buttonStyle(.borderedProminent)

            Button("I'm a Student") {
                signInManager.saveRole("student")
                goToHome = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .fullScreenCover(isPresented: $goToHome) {
                    // Navigate to correct home
                    if let role = signInManager.currentUser?.role {
                        if role == "parent" {
                            ParentDashboard()
                        } else {
                            StudentDashboard()
                        }
                    }
                }
    }
}


