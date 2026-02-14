//
//  AcceptInviteView.swift
//  HatchEd
//
//  Shown when the app is opened via an invite link. Child accepts and is signed in.
//

import SwiftUI

struct AcceptInviteView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let token: String

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didAccept = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.hatchEdAccent)
            Text("You're invited to join a family on HatchEd")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.hatchEdText)
                .multilineTextAlignment(.center)
            Text("Tap Accept to sign in and access your account. Everything your parent has set up for you will be ready.")
                .font(.body)
                .foregroundColor(.hatchEdSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.hatchEdCoralAccent)
                    .multilineTextAlignment(.center)
            }

            if didAccept {
                ProgressView("Signing you in…")
            } else {
                Button(action: acceptInvite) {
                    Text("Accept invite")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.hatchEdAccent)
                .disabled(isLoading)

                Button(action: {
                    authViewModel.clearPendingInviteToken()
                }) {
                    Text("Not now")
                        .foregroundColor(.hatchEdSecondaryText)
                }
                .disabled(isLoading)
            }
            Spacer()
        }
        .padding()
    }

    private func acceptInvite() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let response = try await APIClient.shared.acceptInvite(token: token)
                await MainActor.run {
                    didAccept = true
                    authViewModel.completeInviteSignIn(token: response.token, user: response.user)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
