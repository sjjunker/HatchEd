//
//  LoginView.swift
//  HatchEd
//
//  Created by Sandi Junker using ChatGPT on 5/6/25.
//
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Your App")
                .font(.largeTitle)
                .bold()

            SignInWithAppleButton(
                onRequest: { request in
                    let prepared = authVM.signInWithAppleRequest()
                    request.requestedScopes = prepared.requestedScopes
                    request.nonce = prepared.nonce
                },
                onCompletion: { result in
                    authVM.handleAuthResult(result)
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal)
        }
    }
}

