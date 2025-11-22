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
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .cornerRadius(26)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Text("Welcome to HatchEd")
                    .font(.largeTitle.bold())
                    .foregroundColor(.hatchEdText)
                
                Text("Sign in with Apple to continue")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
            }
            .padding(.top, 60)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                signInManager.handleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hatchEdBackground)
    }
}


