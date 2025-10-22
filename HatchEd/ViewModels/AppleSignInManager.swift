//
//  AppleSignInManager.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import AuthenticationServices
import SwiftUI

@MainActor
final class AppleSignInManager: NSObject, ObservableObject {
    @Published var currentUserID: String? = nil

    func handleAuthorization(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = credential.user
                self.currentUserID = userID
                print("✅ Signed in with Apple ID:", userID)
            }
        case .failure(let error):
            print("❌ Apple Sign-In failed:", error.localizedDescription)
        }
    }
}

