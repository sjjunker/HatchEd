//
//  LoginView.swift
//  HatchEd
//
//  Created by Sandi Junker using ChatGPT on 5/6/25.
//
import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showUsernamePasswordSignIn = false
    @State private var showInviteLinkEntry = false
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .cornerRadius(26)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Text("Welcome to HatchEd")
                    .font(.largeTitle.bold())
                    .foregroundColor(.hatchEdText)
                
                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
            }
            .padding(.top, 60)

            VStack(spacing: 16) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authViewModel.handleSignIn(result: result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(12)
                
                Button(action: {
                    handleGoogleSignIn()
                }) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 18))
                        Text("Sign in with Google")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 0.26, green: 0.52, blue: 0.96))
                    .cornerRadius(12)
                }
                
                Button(action: {
                    showUsernamePasswordSignIn = true
                }) {
                    HStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                        Text("Sign in with Username")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(.hatchEdText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.hatchEdSecondaryBackground)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    showInviteLinkEntry = true
                }) {
                    HStack {
                        Image(systemName: "link")
                            .font(.system(size: 18))
                        Text("I have an invite link")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(.hatchEdAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.hatchEdAccentBackground)
                    .cornerRadius(12)
                }
            }
            .sheet(isPresented: $showUsernamePasswordSignIn) {
                UsernamePasswordSignInView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showInviteLinkEntry) {
                InviteLinkEntryView(
                    onTokenEntered: { token in
                        showInviteLinkEntry = false
                        authViewModel.pendingInviteToken = token
                    },
                    onDismiss: {
                        showInviteLinkEntry = false
                    }
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hatchEdBackground)
        .onAppear {
            configureGoogleSignIn()
        }
    }
    
    private func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("[Google Sign-In] Warning: GoogleService-Info.plist not found or CLIENT_ID missing")
            return
        }
        
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
    }
    
    private func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("[Google Sign-In] Failed to get presenting view controller")
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                print("[Google Sign-In] Failed: \(error.localizedDescription)")
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("[Google Sign-In] Failed: Missing user or ID token")
                return
            }
            
            let fullName = user.profile?.name
            let email = user.profile?.email
            
            Task { @MainActor in
                authViewModel.handleGoogleSignIn(
                    idToken: idToken,
                    fullName: fullName,
                    email: email
                )
            }
        }
    }
}

// MARK: - Invite link entry (paste link or token on sign-in page)
private func parseInviteToken(from input: String) -> String? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    // URL format: hatched://invite?token=... or https://.../invite?token=...
    if let url = URL(string: trimmed),
       let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let token = components.queryItems?.first(where: { $0.name == "token" })?.value, !token.isEmpty {
        return token
    }
    // Otherwise treat as raw token (code or full link that didn't parse as URL with token=)
    return trimmed
}

struct InviteLinkEntryView: View {
    @State private var linkOrTokenInput = ""
    @State private var errorMessage: String?
    var onTokenEntered: (String) -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Paste the invite link your parent sent you, or paste just the invite code.")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                
                TextField("Invite link or code", text: $linkOrTokenInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sign in with invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        guard let token = parseInviteToken(from: linkOrTokenInput) else {
                            errorMessage = "Please paste a valid invite link or code."
                            return
                        }
                        errorMessage = nil
                        onTokenEntered(token)
                    }
                }
            }
        }
    }
}


