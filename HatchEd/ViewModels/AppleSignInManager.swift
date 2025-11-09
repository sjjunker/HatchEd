//
//  AppleSignInManager.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//

import AuthenticationServices
import SwiftUI

enum SignInState {
    case notSignedIn
    case needsRoleSelection
    case signedIn
}

@MainActor
class AppleSignInManager: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var currentFamily: Family?
    @Published var students: [User] = []
    @Published var signInState: SignInState = .notSignedIn
    @Published var isOffline: Bool = false

    private let appleIDProvider = ASAuthorizationAppleIDProvider()
    private let api = APIClient.shared
    private let cache = OfflineCache.shared

    override init() {
        super.init()
        loadCachedData()
        checkExistingSignIn()
    }

    var isSignedIn: Bool { currentUser != nil }
    var userRole: String? { currentUser?.role }
    var needsRoleSelection: Bool { currentUser != nil && (currentUser?.role?.isEmpty ?? true) }
    var studentRequiresFamily: Bool { currentUser?.role == "student" && currentUser?.familyId == nil }

    @ViewBuilder
    var dashboardView: some View {
        if let role = userRole {
            switch role {
            case "parent":
                ParentDashboard()
            case "student":
                if studentRequiresFamily {
                    StudentJoinFamilyView()
                } else {
                    StudentDashboard()
                }
            default:
                SignInView()
            }
        } else {
            SignInView()
        }
    }

    func checkExistingSignIn() {
        guard let storedUserID = getStoredUserID(), !storedUserID.isEmpty else {
            updateSignInState()
            return
        }

        appleIDProvider.getCredentialState(forUserID: storedUserID) { [weak self] credentialState, _ in
            Task { @MainActor in
                switch credentialState {
                case .authorized:
                    await self?.refreshFromServer()
                case .revoked, .notFound:
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }

    private func updateSignInState() {
        guard let user = currentUser else {
            signInState = .notSignedIn
            return
        }
        if let role = user.role, !role.isEmpty {
            signInState = .signedIn
        } else {
            signInState = .needsRoleSelection
        }
    }

    func signOut() {
        currentUser = nil
        currentFamily = nil
        students = []
        clearStoredUserID()
        api.setAuthToken(nil)
        cache.wipeAll()
        updateSignInState()
    }

    private func getStoredUserID() -> String? {
        UserDefaults.standard.string(forKey: "currentUserID")
    }

    private func storeUserID(_ userID: String) {
        UserDefaults.standard.set(userID, forKey: "currentUserID")
    }

    private func clearStoredUserID() {
        UserDefaults.standard.removeObject(forKey: "currentUserID")
    }

    private func refreshFromServer() async {
        do {
            let response: UserResponse = try await api.request(Endpoint(path: "api/users/me"))
            applyUser(response.user)
            await fetchFamilyIfNeeded()
            isOffline = false
        } catch {
            if let cachedUser: User = cache.load(User.self, from: "user.json") {
                applyUser(cachedUser)
            }
            if let cachedFamily: Family = cache.load(Family.self, from: "family.json") {
                currentFamily = cachedFamily
            }
            if let cachedStudents: [User] = cache.load([User].self, from: "students.json") {
                students = cachedStudents
            }
            isOffline = true
            updateSignInState()
        }
    }

    private func fetchFamilyIfNeeded() async {
        guard let familyId = currentUser?.familyId else {
            currentFamily = nil
            students = []
            cache.remove("family.json")
            cache.remove("students.json")
            return
        }
        do {
            let response: FamilyDetailResponse = try await api.request(Endpoint(path: "api/families/\(familyId)"))
            currentFamily = response.family
            students = response.students
            cache.save(response.family, as: "family.json")
            cache.save(response.students, as: "students.json")
        } catch {
            print("Failed to fetch family: \(error)")
        }
    }

    private func loadCachedData() {
        if let user: User = cache.load(User.self, from: "user.json") {
            currentUser = user
        }
        if let family: Family = cache.load(Family.self, from: "family.json") {
            currentFamily = family
        }
        if let students: [User] = cache.load([User].self, from: "students.json") {
            self.students = students
        }
        updateSignInState()
    }

    private func applyUser(_ user: User) {
        currentUser = user
        cache.save(user, as: "user.json")
        updateSignInState()
    }

    func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            Task { await processSignIn(authResults: authResults) }
        case .failure(let error):
            print("Apple Sign-In failed: \(error.localizedDescription)")
            signInState = .notSignedIn
        }
    }

    private func processSignIn(authResults: ASAuthorization) async {
        guard let credential = authResults.credential as? ASAuthorizationAppleIDCredential else {
            signInState = .notSignedIn
            return
        }

        let userId = credential.user
        let name = credential.fullName?.givenName
        let email = credential.email

        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            signInState = .notSignedIn
            return
        }

        do {
            let body = AuthRequest(identityToken: identityToken, fullName: name, email: email)
            let response: AuthResponse = try await api.request(
                Endpoint(path: "api/auth/apple", method: .post, body: body)
            )
            api.setAuthToken(response.token)
            storeUserID(userId)
            applyUser(response.user)
            cache.save(response.token, as: "token.json")
            await fetchFamilyIfNeeded()
        } catch {
            print("Apple Sign-In exchange failed: \(error.localizedDescription)")
            signInState = .notSignedIn
        }
    }

    func saveRole(_ role: String) {
        Task {
            do {
                let request = UpdateUserRequest(role: role, name: nil)
                let response: UserResponse = try await api.request(
                    Endpoint(path: "api/users/me", method: .patch, body: request)
                )
                applyUser(response.user)
            } catch {
                print("Failed to update role: \(error)")
            }
        }
    }

    func updateUserName(_ name: String) {
        Task {
            do {
                let request = UpdateUserRequest(role: nil, name: name)
                let response: UserResponse = try await api.request(
                    Endpoint(path: "api/users/me", method: .patch, body: request)
                )
                applyUser(response.user)
            } catch {
                print("Failed to update name: \(error)")
            }
        }
    }

    func updateUserFromDatabase() {
        Task { await refreshFromServer() }
    }

    enum FamilyJoinError: LocalizedError {
        case noCurrentUser
        case invalidCode
        case invalidName
        case familyNotFound
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noCurrentUser:
                return "Unable to determine the current user. Please sign in again."
            case .invalidCode:
                return "Enter the join code provided by your parent or guardian."
            case .invalidName:
                return "Please enter a family name."
            case .familyNotFound:
                return "We couldn't find a family with that join code. Double-check and try again."
            case .saveFailed(let error):
                return "We couldn't add you to the family. Please try again. (\(error.localizedDescription))"
            }
        }
    }

    func joinFamily(with joinCode: String) async throws {
        guard currentUser != nil else {
            throw FamilyJoinError.noCurrentUser
        }

        let trimmedCode = joinCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !trimmedCode.isEmpty else {
            throw FamilyJoinError.invalidCode
        }

        do {
            let request = JoinFamilyRequest(joinCode: trimmedCode)
            let response: FamilyResponse = try await api.request(
                Endpoint(path: "api/users/me/family/join", method: .post, body: request)
            )
            currentFamily = response.family
            cache.save(response.family, as: "family.json")
            await refreshFromServer()
        } catch let error as APIError {
            switch error {
            case .server(_, _, let status) where status == 404:
                throw FamilyJoinError.familyNotFound
            default:
                throw FamilyJoinError.saveFailed(error)
            }
        } catch {
            throw FamilyJoinError.saveFailed(error)
        }
    }

    func createFamily(named name: String) async throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FamilyJoinError.invalidName
        }
        do {
            let request = CreateFamilyRequest(name: name)
            let response: FamilyResponse = try await api.request(
                Endpoint(path: "api/users/me/family", method: .post, body: request)
            )
            currentFamily = response.family
            cache.save(response.family, as: "family.json")
            await refreshFromServer()
        } catch {
            throw FamilyJoinError.saveFailed(error)
        }
    }
}

struct AuthRequest: Encodable {
    let identityToken: String
    let fullName: String?
    let email: String?
}

struct AuthResponse: Decodable {
    let token: String
    let user: User
}

struct UserResponse: Decodable {
    let user: User
}

struct UpdateUserRequest: Encodable {
    let role: String?
    let name: String?
}

struct FamilyResponse: Decodable {
    let family: Family
}

struct JoinFamilyRequest: Encodable {
    let joinCode: String
}

struct FamilyDetailResponse: Decodable {
    let family: Family
    let students: [User]
}

struct CreateFamilyRequest: Encodable {
    let name: String
}

