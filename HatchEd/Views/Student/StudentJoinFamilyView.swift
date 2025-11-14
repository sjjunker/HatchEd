//
//  StudentJoinFamilyView.swift
//  HatchEd
//
//  Created by ChatGPT on 11/7/25.
//

import SwiftUI

struct StudentJoinFamilyView: View {
    @EnvironmentObject private var signInManager: AppleSignInManager
    @State private var joinCode: String = ""
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    
    private var trimmedCode: String {
        joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isJoinDisabled: Bool {
        isSubmitting || trimmedCode.count < 6
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter the family join code")) {
                    TextField("Family Code", text: $joinCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isTextFieldFocused)
                }
                
                if let errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.hatchEdCoralAccent)
                            Text(errorMessage)
                                .foregroundColor(.hatchEdCoralAccent)
                        }
                    }
                }
                
                Section(footer: Text("Ask your parent or guardian for the six-character code they created in Settings.")
                    .foregroundColor(.hatchEdSecondaryText)) {
                    Button {
                        submitJoin()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.hatchEdWhite)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Join Family")
                                .fontWeight(.semibold)
                                .foregroundColor(.hatchEdWhite)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.hatchEdAccent)
                    .disabled(isJoinDisabled)
                }
            }
            .navigationTitle("Join Family")
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
        }
    }
    
    private func submitJoin() {
        let code = trimmedCode
        guard !code.isEmpty else {
            errorMessage = "Please enter your family join code."
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await signInManager.joinFamily(with: code)
                await MainActor.run {
                    joinCode = ""
                    isSubmitting = false
                }
            } catch let error as AppleSignInManager.FamilyJoinError {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}


