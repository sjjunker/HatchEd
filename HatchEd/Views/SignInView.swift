//
//  LoginView.swift
//  HatchEd
//
//  Created by Sandi Junker using ChatGPT on 5/6/25.
//
import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var signInManager: AppleSignInManager
    @State private var isSignedIn = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to HatchEd")
                .font(.largeTitle.bold())
                .padding(.top, 40)
            
            Text("Sign in with Apple to continue")
                .foregroundStyle(.secondary)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                signInManager.handleAuthorization(result: result)
                if signInManager.currentUserID != nil {
                    isSignedIn = true
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(8)
        }
        .padding()
        .fullScreenCover(isPresented: $isSignedIn) {
            // 👇 Navigate to RoleSelectionView
            if let userID = signInManager.currentUserID {
                RoleSelectionView(userID: userID)
            }
        }
    }
}


