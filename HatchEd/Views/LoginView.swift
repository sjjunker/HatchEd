//
//  LoginView.swift
//  HatchEd
//
//  Created by Sandi Junker using ChatGPT on 5/6/25.
//
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var signInManager: AppleSignInManager

    var body: some View {
        VStack {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                if case .failure(let error) = result {
                    print("Sign-in failed: \(error.localizedDescription)")
                }
                // Handle the sign-in result inside the AppleSignInManager
                signInManager.signInWithApple()
            }
            .frame(height: 50)
            .padding()
        }
    }
}



