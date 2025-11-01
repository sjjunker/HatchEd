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
        VStack(spacing: 24) {
            Text("Welcome to HatchEd")
                .font(.largeTitle.bold())
                .padding(.top, 40)
            
            Text("Sign in with Apple to continue")
                .foregroundStyle(.secondary)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                signInManager.handleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(8)
        }
        .padding()
    }
}


