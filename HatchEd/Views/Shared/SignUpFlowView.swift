//
//  SignUpFlowView.swift
//  HatchEd
//
//  Sign-up funnel: role → parent or student (invite verify) → Apple / Google / username.
//

import AuthenticationServices
import GoogleSignIn
import SwiftUI
import UIKit

struct SignUpFlowView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case role
        case parentMethods
        case studentInvite
        case studentMethods
    }

    @State private var step: Step = .role
    @State private var verifiedInviteToken: String?
    @State private var showAuthNotice = false

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .role:
                    RoleSelectionView(
                        isSignupFlow: true,
                        onSignupParent: { step = .parentMethods },
                        onSignupStudent: { step = .studentInvite }
                    )
                case .parentMethods:
                    SignUpMethodPickerView(
                        title: "Parent account",
                        subtitle: "Choose how you want to sign in",
                        oauthIntent: .signUp,
                        role: "parent",
                        inviteToken: nil,
                        onBack: { step = .role }
                    )
                case .studentInvite:
                    StudentInviteVerifyStep(
                        onVerified: { token in
                            verifiedInviteToken = token
                            step = .studentMethods
                        },
                        onBack: { step = .role }
                    )
                case .studentMethods:
                    if let token = verifiedInviteToken {
                        SignUpMethodPickerView(
                            title: "Student account",
                            subtitle: "Link a sign-in method to your invite",
                            oauthIntent: .signIn,
                            role: nil,
                            inviteToken: token,
                            onBack: { step = .studentInvite }
                        )
                    } else {
                        Text("Missing invite").foregroundColor(.hatchEdSecondaryText)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { configureGoogleSignIn() }
        .onChange(of: authViewModel.isSignedIn) { _, signedIn in
            if signedIn { dismiss() }
        }
        .onChange(of: authViewModel.authNotice) { _, newValue in
            showAuthNotice = newValue != nil
        }
        .alert("Sign up", isPresented: $showAuthNotice) {
            Button("OK", role: .cancel) {
                authViewModel.clearAuthNotice()
            }
        } message: {
            Text(authViewModel.authNotice ?? "")
        }
    }

    private func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
}

// MARK: - Invite verify (student)

private struct StudentInviteVerifyStep: View {
    @State private var linkOrTokenInput = ""
    @State private var errorMessage: String?
    @State private var verifiedName: String?
    @State private var isVerifying = false

    var onVerified: (String) -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your parent should send you an invite link or code. Paste it here so we can verify it before you create your account.")
                .font(.subheadline)
                .foregroundColor(.hatchEdSecondaryText)

            TextField("Invite link or code", text: $linkOrTokenInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if let verifiedName, !verifiedName.isEmpty {
                Text("Verified for: \(verifiedName)")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdAccent)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: { Task { await verify() } }) {
                HStack {
                    if isVerifying { ProgressView() }
                    Text(isVerifying ? "Verifying…" : "Verify invite")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.hatchEdAccent)
            .disabled(isVerifying || parseInviteToken(from: linkOrTokenInput) == nil)

            Button("Continue") {
                if let t = parseInviteToken(from: linkOrTokenInput) {
                    onVerified(t)
                }
            }
            .buttonStyle(.bordered)
            .tint(.hatchEdAccent)
            .disabled(parseInviteToken(from: linkOrTokenInput) == nil || verifiedName == nil)

            Spacer()
        }
        .padding()
        .navigationTitle("Student invite")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back", action: onBack)
            }
        }
    }

    private func verify() async {
        guard let token = parseInviteToken(from: linkOrTokenInput) else {
            errorMessage = "Please paste a valid invite link or code."
            return
        }
        isVerifying = true
        errorMessage = nil
        verifiedName = nil
        defer { isVerifying = false }
        do {
            let r = try await APIClient.shared.validateInvite(token: token)
            if r.valid {
                verifiedName = r.name ?? "Student"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Method picker (OAuth + username)

private struct SignUpMethodPickerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showUsernameSignUp = false

    let title: String
    let subtitle: String
    let oauthIntent: OAuthIntent
    let role: String?
    let inviteToken: String?
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundColor(.hatchEdText)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(spacing: 16) {
                SignInWithAppleButton(
                    oauthIntent == .signUp ? .signUp : .signIn
                ) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authViewModel.handleSignIn(
                        result: result,
                        intent: oauthIntent,
                        inviteToken: inviteToken,
                        role: role
                    )
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(12)

                Button(action: { runGoogleSignUp() }) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 18))
                        Text("Continue with Google")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 0.26, green: 0.52, blue: 0.96))
                    .cornerRadius(12)
                }

                Button(action: { showUsernameSignUp = true }) {
                    HStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                        Text("Continue with Username")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(.hatchEdText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.hatchEdSecondaryBackground)
                    .cornerRadius(12)
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hatchEdBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back", action: onBack)
            }
        }
        .sheet(isPresented: $showUsernameSignUp) {
            UsernamePasswordSignUpView(
                inviteToken: inviteToken,
                role: role
            )
            .environmentObject(authViewModel)
        }
    }

    private func runGoogleSignUp() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error {
                print("[Google Sign-Up] \(error.localizedDescription)")
                return
            }
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                return
            }
            let fullName = user.profile?.name
            let email = user.profile?.email
            Task { @MainActor in
                authViewModel.handleGoogleSignIn(
                    idToken: idToken,
                    fullName: fullName,
                    email: email,
                    intent: oauthIntent,
                    inviteToken: inviteToken,
                    role: role
                )
            }
        }
    }
}

private func parseInviteToken(from input: String) -> String? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let url = URL(string: trimmed),
       let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let token = components.queryItems?.first(where: { $0.name == "token" })?.value, !token.isEmpty {
        return token
    }
    return trimmed
}
