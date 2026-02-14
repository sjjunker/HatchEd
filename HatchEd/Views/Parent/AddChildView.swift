//
//  AddChildView.swift
//  HatchEd
//
//  Parent adds a child; child is created immediately. Invite link is shown for the child to activate their account.
//

import SwiftUI

private let testFlightURL = URL(string: "https://testflight.apple.com/join/U1p9F3Rn")!

struct AddChildView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var didAddChild: Bool

    @State private var name = ""
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var inviteLink: String?
    @State private var inviteToken: String?
    @State private var addedChildName: String?

    var body: some View {
        NavigationView {
            Group {
                if inviteLink != nil {
                    inviteSuccessContent
                } else {
                    formContent
                }
            }
            .navigationTitle("Add Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var formContent: some View {
        Form {
            Section {
                TextField("Child's name", text: $name)
                    .textContentType(.name)
                TextField("Email (optional)", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            } header: {
                Text("Child details")
            } footer: {
                Text("The child will be added to your family. Send them the invite link so they can open the app and access their account.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.hatchEdCoralAccent)
                }
            }

            Section {
                Button(action: addChild) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isLoading ? "Adding…" : "Add Child")
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
        }
    }

    private var inviteSuccessContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let addedChildName {
                    Text("\(addedChildName) has been added to your family.")
                        .font(.headline)
                        .foregroundColor(.hatchEdText)
                }
                Text("Send the link below to your child. When they open it and accept, they can use the app and see everything you've set up for them.")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)

                if let link = inviteLink {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invite link (share with your child)")
                            .font(.caption)
                            .foregroundColor(.hatchEdSecondaryText)
                        Text(link)
                            .font(.caption)
                            .foregroundColor(.hatchEdText)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.hatchEdCardBackground)
                            .cornerRadius(8)
                        Button(action: { UIPasteboard.general.string = link }) {
                            Label("Copy link", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.hatchEdAccent)
                    }
                    if let token = inviteToken, !token.isEmpty {
                        let appLink = "hatched://invite?token=\(token)"
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Or copy this app link (opens HatchEd when tapped)")
                                .font(.caption)
                                .foregroundColor(.hatchEdSecondaryText)
                            Button(action: { UIPasteboard.general.string = appLink }) {
                                Label("Copy app link", systemImage: "link")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Text("Your child will need the HatchEd app.")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                Button(action: {
                    UIApplication.shared.open(testFlightURL)
                }) {
                    Label("Get the app (TestFlight)", systemImage: "arrow.down.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    private func addChild() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let response = try await APIClient.shared.createChild(name: trimmedName, email: email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email.trimmingCharacters(in: .whitespaces))
                await MainActor.run {
                    inviteLink = response.inviteLink
                    inviteToken = response.inviteToken
                    addedChildName = response.child.name
                    didAddChild = true
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
