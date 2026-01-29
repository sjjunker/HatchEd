//
//  AuthViewModel.swift
//  HatchEd
//
//  MVVM: ViewModel for authentication and session state.
//

import AuthenticationServices
import SwiftUI

enum SignInState {
    case notSignedIn
    case needsRoleSelection
    case signedIn
}

@MainActor
class AuthViewModel: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var currentFamily: Family?
    @Published var students: [User] = []
    @Published var notifications: [Notification] = []
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
        notifications = []
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
            await fetchNotifications()
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
            if let cachedNotifications: [Notification] = cache.load([Notification].self, from: "notifications.json") {
                notifications = cachedNotifications
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
        if let cachedNotifications: [Notification] = cache.load([Notification].self, from: "notifications.json") {
            self.notifications = cachedNotifications
        }
        updateSignInState()
    }

    private func applyUser(_ user: User) {
        currentUser = user
        cache.save(user, as: "user.json")
        updateSignInState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if self?.signInState == .signedIn && self?.userRole == nil {
                self?.signInState = .needsRoleSelection
            }
        }
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

    func handleGoogleSignIn(idToken: String, fullName: String?, email: String?) {
        Task { await processGoogleSignIn(idToken: idToken, fullName: fullName, email: email) }
    }

    func handleUsernamePasswordSignIn(username: String, password: String, twoFactorCode: String? = nil) async throws {
        let body = UsernamePasswordSignInRequest(username: username, password: password, twoFactorCode: twoFactorCode)
        let response: AuthResponse = try await api.request(
            Endpoint(path: "api/auth/signin", method: .post, body: body)
        )
        if response.requiresTwoFactor == true {
            throw TwoFactorRequiredError(userId: response.userId ?? "")
        }
        guard let token = response.token, let user = response.user else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        api.setAuthToken(token)
        if let userId = user.id as String? { storeUserID(userId) }
        applyUser(user)
        try? await Task.sleep(nanoseconds: 100_000_000)
        cache.save(token, as: "token.json")
        await fetchFamilyIfNeeded()
        await fetchNotifications()
    }

    func handleUsernamePasswordSignUp(username: String, password: String, email: String?, name: String?) async throws {
        let body = UsernamePasswordSignUpRequest(username: username, password: password, email: email, name: name)
        let response: AuthResponse = try await api.request(
            Endpoint(path: "api/auth/signup", method: .post, body: body)
        )
        guard let token = response.token, let user = response.user else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        api.setAuthToken(token)
        if let userId = user.id as String? { storeUserID(userId) }
        applyUser(user)
        try? await Task.sleep(nanoseconds: 100_000_000)
        cache.save(token, as: "token.json")
        await fetchFamilyIfNeeded()
        await fetchNotifications()
    }

    private func processGoogleSignIn(idToken: String, fullName: String?, email: String?) async {
        do {
            let body = GoogleAuthRequest(idToken: idToken, fullName: fullName, email: email)
            let response: AuthResponse = try await api.request(
                Endpoint(path: "api/auth/google", method: .post, body: body)
            )
            guard let token = response.token, let user = response.user else {
                throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
            }
            api.setAuthToken(token)
            if let userId = user.id as String? { storeUserID(userId) }
            applyUser(user)
            try? await Task.sleep(nanoseconds: 100_000_000)
            cache.save(token, as: "token.json")
            await fetchFamilyIfNeeded()
            await fetchNotifications()
        } catch {
            print("Google sign-in failed: \(error.localizedDescription)")
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
            guard let token = response.token, let user = response.user else {
                throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
            }
            api.setAuthToken(token)
            storeUserID(userId)
            applyUser(user)
            try? await Task.sleep(nanoseconds: 100_000_000)
            cache.save(token, as: "token.json")
            await fetchFamilyIfNeeded()
            await fetchNotifications()
        } catch {
            print("Apple sign-in failed: \(error.localizedDescription)")
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
            case .noCurrentUser: return "Unable to determine the current user. Please sign in again."
            case .invalidCode: return "Enter the join code provided by your parent or guardian."
            case .invalidName: return "Please enter a family name."
            case .familyNotFound: return "We couldn't find a family with that join code."
            case .saveFailed(let error): return "We couldn't add you to the family. (\(error.localizedDescription))"
            }
        }
    }

    func joinFamily(with joinCode: String) async throws {
        guard currentUser != nil else { throw FamilyJoinError.noCurrentUser }
        let trimmedCode = joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmedCode.isEmpty else { throw FamilyJoinError.invalidCode }
        do {
            let request = JoinFamilyRequest(joinCode: trimmedCode)
            let response: FamilyResponse = try await api.request(
                Endpoint(path: "api/users/me/family/join", method: .post, body: request)
            )
            currentFamily = response.family
            cache.save(response.family, as: "family.json")
            await refreshFromServer()
        } catch let error as APIError {
            if case .server(_, _, let status) = error, status == 404 {
                throw FamilyJoinError.familyNotFound
            }
            throw FamilyJoinError.saveFailed(error)
        } catch {
            throw FamilyJoinError.saveFailed(error)
        }
    }

    func createFamily(named name: String) async throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FamilyJoinError.invalidName
        }
        let request = CreateFamilyRequest(name: name)
        let response: FamilyResponse = try await api.request(
            Endpoint(path: "api/users/me/family", method: .post, body: request)
        )
        currentFamily = response.family
        cache.save(response.family, as: "family.json")
        await refreshFromServer()
    }

    func fetchNotifications() async {
        guard api.getAuthToken() != nil else { return }
        do {
            let response: NotificationsResponse = try await api.request(Endpoint(path: "api/notifications"))
            notifications = response.notifications
            cache.save(response.notifications, as: "notifications.json")
        } catch {
            print("Failed to fetch notifications: \(error)")
        }
    }

    func deleteNotification(_ notification: Notification) async {
        guard api.getAuthToken() != nil else { return }
        do {
            _ = try await api.request(Endpoint(path: "api/notifications/\(notification.id)", method: .delete), responseType: EmptyResponse.self)
            notifications.removeAll { $0.id == notification.id }
            cache.save(notifications, as: "notifications.json")
        } catch {
            print("Failed to delete notification: \(error)")
        }
    }

    func submitAttendance(date: Date, attendanceStatus: [String: Bool]) async throws -> AttendanceSubmissionResponse {
        let records = attendanceStatus.map { AttendanceSubmissionRecord(studentUserId: $0.key, isPresent: $0.value) }
        return try await api.submitAttendance(date: date, records: records)
    }
}

// MARK: - Auth API DTOs (used only by AuthViewModel)
struct AuthRequest: Encodable {
    let identityToken: String
    let fullName: String?
    let email: String?
}
struct GoogleAuthRequest: Encodable {
    let idToken: String
    let fullName: String?
    let email: String?
}
struct UsernamePasswordSignInRequest: Encodable {
    let username: String
    let password: String
    let twoFactorCode: String?
    init(username: String, password: String, twoFactorCode: String? = nil) {
        self.username = username
        self.password = password
        self.twoFactorCode = twoFactorCode
    }
}
struct UsernamePasswordSignUpRequest: Encodable {
    let username: String
    let password: String
    let email: String?
    let name: String?
}
struct AuthResponse: Decodable {
    let token: String?
    let user: User?
    let requiresTwoFactor: Bool?
    let userId: String?
    let message: String?
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
struct TwoFactorRequiredError: LocalizedError {
    let userId: String
    var errorDescription: String? { "Two-factor authentication code required" }
}
struct CreateFamilyRequest: Encodable {
    let name: String
}
struct NotificationsResponse: Decodable {
    let notifications: [Notification]
}
