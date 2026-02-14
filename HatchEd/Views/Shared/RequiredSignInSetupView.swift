//
//  RequiredSignInSetupView.swift
//  HatchEd
//
//  Shown after a child accepts an invite. Not dismissable until they add a sign-in method.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct RequiredSignInSetupView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    var onComplete: () -> Void

    @State private var showSetUsernamePassword = false
    @State private var errorMessage: String?
    @State private var isLinking = false

    private var currentUser: User? { authViewModel.currentUser }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Set up sign-in")
                        .font(.title.bold())
                        .foregroundColor(.hatchEdText)
                    Text("Add a sign-in method so you can get back into your account later if you sign out or switch devices. You’ll need to complete this before continuing.")
                        .font(.body)
                        .foregroundColor(.hatchEdSecondaryText)

                    VStack(spacing: 16) {
                        if (currentUser?.appleId ?? "").isEmpty {
                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                handleLinkAppleCompletion(result)
                            }
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 50)
                            .cornerRadius(12)
                            .disabled(isLinking)
                        }
                        if (currentUser?.googleId ?? "").isEmpty {
                            Button {
                                Task { await handleLinkGoogle() }
                            } label: {
                                HStack {
                                    Image(systemName: "globe")
                                    Text("Link Google account")
                                }
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(red: 0.26, green: 0.52, blue: 0.96))
                                .cornerRadius(12)
                            }
                            .disabled(isLinking)
                        }
                        if (currentUser?.username ?? "").isEmpty {
                            Button {
                                showSetUsernamePassword = true
                            } label: {
                                Label("Set username & password", systemImage: "person.badge.key.fill")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.hatchEdText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.hatchEdSecondaryBackground)
                                    .cornerRadius(12)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.hatchEdCoralAccent)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(true)
            .sheet(isPresented: $showSetUsernamePassword) {
                SetUsernamePasswordSheet(
                    currentUsername: currentUser?.username,
                    onSave: { username, password in
                        Task { await performSetUsernamePassword(username: username, password: password) }
                    },
                    onDismiss: { }
                )
            }
            .onAppear {
                configureGoogleSignInIfNeeded()
            }
        }
    }

    private func configureGoogleSignInIfNeeded() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else { return }
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
    }

    private func handleLinkAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            guard let cred = authResults.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Could not get Apple sign-in token."
                return
            }
            Task { await performLinkApple(identityToken: token) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func performLinkApple(identityToken: String) async {
        isLinking = true
        errorMessage = nil
        defer { isLinking = false }
        do {
            let response: UserResponse = try await APIClient.shared.linkApple(identityToken: identityToken)
            await MainActor.run {
                authViewModel.updateCurrentUser(response.user)
                onComplete()
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func handleLinkGoogle() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        isLinking = true
        errorMessage = nil
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
            await MainActor.run { isLinking = false }
            guard let idToken = result.user.idToken?.tokenString else {
                await MainActor.run { errorMessage = "Could not get Google sign-in token." }
                return
            }
            let response: UserResponse = try await APIClient.shared.linkGoogle(idToken: idToken)
            await MainActor.run {
                authViewModel.updateCurrentUser(response.user)
                onComplete()
            }
        } catch {
            await MainActor.run {
                isLinking = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func performSetUsernamePassword(username: String?, password: String?) async {
        do {
            let response: UserResponse = try await APIClient.shared.setUsernamePassword(username: username, password: password)
            await MainActor.run {
                authViewModel.updateCurrentUser(response.user)
                showSetUsernamePassword = false
                onComplete()
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}
