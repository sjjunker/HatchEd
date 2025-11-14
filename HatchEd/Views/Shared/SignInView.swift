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
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.hatchEdAccent)
                
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


