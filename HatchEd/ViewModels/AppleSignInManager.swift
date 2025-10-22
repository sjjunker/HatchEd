//
//  AppleSignInManager.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import AuthenticationServices
import SwiftUI
import SwiftData

@MainActor
class AppleSignInManager: NSObject, ObservableObject {
    @Published var currentUser: User?
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            guard let credential = authResults.credential as? ASAuthorizationAppleIDCredential else { return }
            let userId = credential.user
            let name = credential.fullName?.givenName
            let email = credential.email

            // Check if user exists
            let fetchDescriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
            if let existingUser = try? modelContext.fetch(fetchDescriptor).first {
                // Existing user
                currentUser = existingUser
            } else {
                // New user → prompt for role
                currentUser = User(id: userId, name: name, email: email)
                modelContext.insert(currentUser!)
                try? modelContext.save()
            }

        case .failure(let error):
            print("Apple Sign-In failed: \(error.localizedDescription)")
        }
    }

    func saveRole(_ role: String) {
        guard let user = currentUser else { return }
        user.role = role
        try? modelContext.save()
    }
}


