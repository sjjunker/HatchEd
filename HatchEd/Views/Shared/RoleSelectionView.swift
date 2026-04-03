//
//  RoleSelectionView.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import SwiftUI

struct RoleSelectionView: View {
    /// When `true`, used from the Sign Up sheet (callbacks instead of saving role for current session).
    var isSignupFlow: Bool = false
    var onSignupParent: (() -> Void)? = nil
    var onSignupStudent: (() -> Void)? = nil

    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 64))
                    .foregroundColor(.hatchEdAccent)

                Text(isSignupFlow ? "Create your account" : "Welcome!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.hatchEdText)

                Text(isSignupFlow ? "Who are you?" : "Who is signing in?")
                    .font(.headline)
                    .foregroundColor(.hatchEdSecondaryText)
            }
            .padding(.top, 60)

            VStack(spacing: 16) {
                Button("I'm a Parent") {
                    if let onSignupParent {
                        onSignupParent()
                    } else {
                        authViewModel.saveRole("parent")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.hatchEdAccent)
                .controlSize(.large)

                Button("I'm a Student") {
                    if let onSignupStudent {
                        onSignupStudent()
                    } else {
                        authViewModel.saveRole("student")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.hatchEdAccent)
                .controlSize(.large)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hatchEdBackground)
    }
}


