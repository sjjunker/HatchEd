//
//  AppleSignInManager.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import AuthenticationServices
import SwiftUI
import SwiftData

enum SignInState {
    case notSignedIn
    case needsRoleSelection
    case signedIn
}

@MainActor
class AppleSignInManager: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var signInState: SignInState = .notSignedIn
    private var modelContext: ModelContext
    private let appleIDProvider = ASAuthorizationAppleIDProvider()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init()
        checkExistingSignIn()
    }
    
    // MARK: - Public Properties
    
    /// Determines if user is signed in
    var isSignedIn: Bool {
        return currentUser != nil
    }
    
    /// Returns the user's role if available
    var userRole: String? {
        return currentUser?.role
    }
    
    /// Determines if user needs to select a role
    var needsRoleSelection: Bool {
        return currentUser != nil && (currentUser?.role == nil || currentUser?.role?.isEmpty == true)
    }
    
    /// Returns the appropriate dashboard view based on user role
    @ViewBuilder
    var dashboardView: some View {
        if let role = userRole {
            if role == "parent" {
                ParentDashboard()
            } else if role == "student" {
                StudentDashboard()
            } else {
                SignInView()
            }
        } else {
            SignInView()
        }
    }
    
    // MARK: - Sign In State Management
    
    func checkExistingSignIn() {
        guard let storedUserID = getStoredUserID(), !storedUserID.isEmpty else {
            updateSignInState()
            return
        }
        
        appleIDProvider.getCredentialState(forUserID: storedUserID) { [weak self] credentialState, error in
            DispatchQueue.main.async {
                switch credentialState {
                case .authorized:
                    // User is signed in, load from database
                    self?.loadUserFromDatabase(userID: storedUserID)
                case .revoked, .notFound:
                    // User is not signed in or revoked
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }
    
    /// Updates the sign-in state based on current user
    private func updateSignInState() {
        if let user = currentUser {
            if let role = user.role, !role.isEmpty {
                signInState = .signedIn
            } else {
                signInState = .needsRoleSelection
            }
        } else {
            signInState = .notSignedIn
        }
    }
    
    /// Signs out the current user
    func signOut() {
        currentUser = nil
        clearStoredUserID()
        updateSignInState()
    }
    
    private func getStoredUserID() -> String? {
        return UserDefaults.standard.string(forKey: "currentUserID")
    }
    
    private func storeUserID(_ userID: String) {
        UserDefaults.standard.set(userID, forKey: "currentUserID")
    }
    
    private func clearStoredUserID() {
        UserDefaults.standard.removeObject(forKey: "currentUserID")
    }
    
    func loadUserFromDatabase(userID: String) {
        let fetchDescriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userID })
        if let user = try? modelContext.fetch(fetchDescriptor).first {
            currentUser = user
            updateSignInState()
        } else {
            signOut()
        }
    }

    // MARK: - Sign In Handling
    
    func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            processSignIn(authResults: authResults)
        case .failure(let error):
            print("Apple Sign-In failed: \(error.localizedDescription)")
            signInState = .notSignedIn
        }
    }
    
    /// Processes a successful sign-in authorization
    private func processSignIn(authResults: ASAuthorization) {
        guard let credential = authResults.credential as? ASAuthorizationAppleIDCredential else {
            signInState = .notSignedIn
            return
        }
        
        let userId = credential.user
        let name = credential.fullName?.givenName
        let email = credential.email

        // Check if user exists in database
        let fetchDescriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
        if let existingUser = try? modelContext.fetch(fetchDescriptor).first {
            // Existing user - update name/email if missing and available
            updateUserInfo(user: existingUser, name: name, email: email)
            currentUser = existingUser
        } else {
            // New user - create and save
            currentUser = User(id: userId, name: name, email: email)
            modelContext.insert(currentUser!)
            try? modelContext.save()
        }
        
        // Store user ID for future app launches
        storeUserID(userId)
        
        // Update sign-in state based on whether user has a role
        updateSignInState()
    }
    
    /// Updates user info if missing
    private func updateUserInfo(user: User, name: String?, email: String?) {
        if user.name == nil, let name = name {
            user.name = name
        }
        if user.email == nil, let email = email {
            user.email = email
        }
        try? modelContext.save()
    }

    // MARK: - Role Management
    
    func saveRole(_ role: String) {
        guard let user = currentUser else { return }
        user.role = role
        try? modelContext.save()
        updateSignInState()
    }
    
    // MARK: - User Data Management
    
    func updateUserName(_ name: String) {
        guard let user = currentUser else { return }
        user.name = name
        try? modelContext.save()
    }
    
    func updateUserFromDatabase() {
        guard let userId = currentUser?.id else { return }
        let fetchDescriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
        if let user = try? modelContext.fetch(fetchDescriptor).first {
            currentUser = user
            updateSignInState()
        }
    }
}


