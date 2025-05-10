//
//  AppleSignInManager.swift
//  HatchEd
//
//  Created by Sandi Junker using ChatGPT on 5/6/25.
//
// AppleSignInManager.swift
//
//  AppleSignInManager.swift
//  HatchEd
//

import AuthenticationServices
import CloudKit
import SwiftUI
import SwiftData

class AppleSignInManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    @Published var currentParent: Parent?
    var modelContext: ModelContext?
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Attempt to return the first window in the current scene
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
    }

    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func handleAuthorization(credential: ASAuthorizationAppleIDCredential) {
        let appleID = credential.user
        let fullName = credential.fullName?.formatted() ?? "Unknown"
        let email = credential.email ?? "Unknown"

        guard let context = modelContext else {
            print("❌ No model context available.")
            return
        }

        // Check if this parent already exists
        let fetchDescriptor = FetchDescriptor<Parent>(
            predicate: #Predicate { $0.email == email }
        )

        do {
            let existing = try context.fetch(fetchDescriptor)
            if let parent = existing.first {
                self.currentParent = parent
                return
            }
        } catch {
            print("Failed to fetch existing parent: \(error)")
        }

        // Create a new parent record
        let newParent = Parent(name: fullName, email: email, appleID: appleID, students: [])
        context.insert(newParent)

        do {
            try context.save()
            self.currentParent = newParent
        } catch {
            print("❌ Failed to save new parent: \(error)")
        }
    }
}

