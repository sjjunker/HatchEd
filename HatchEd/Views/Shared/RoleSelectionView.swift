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
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 64))
                    .foregroundColor(.hatchEdAccent)
                
                Text("Welcome!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.hatchEdText)

                Text("Who is signing in?")
                    .font(.headline)
                    .foregroundColor(.hatchEdSecondaryText)
            }
            .padding(.top, 60)

            VStack(spacing: 16) {
                Button("I'm a Parent") {
                    signInManager.saveRole("parent")
                }
                .buttonStyle(.borderedProminent)
                .tint(.hatchEdAccent)
                .controlSize(.large)

                Button("I'm a Student") {
                    signInManager.saveRole("student")
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


