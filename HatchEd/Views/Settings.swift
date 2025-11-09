//
//  Settings.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/3/25.
//

import SwiftUI

struct Settings: View {
    @EnvironmentObject private var signInManager: AppleSignInManager
    @State private var showingCreateFamily = false
    @State private var showingJoinFamily = false
    @State private var newFamilyName = ""
    @State private var joinCode = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    
    private var currentUser: User? {
        signInManager.currentUser
    }
    
    private var isParent: Bool {
        currentUser?.role == "parent"
    }
    
    private var currentFamily: Family? {
        signInManager.currentFamily
    }
    
    var body: some View {
        NavigationView {
            Form {
                if isParent {
                    familySection
                } else {
                    Text("Family settings are only available for parent accounts.")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingCreateFamily) {
            createFamilySheet
        }
        .sheet(isPresented: $showingJoinFamily) {
            joinFamilySheet
        }
    }
    
    // MARK: - Family Section
    
    private var familySection: some View {
        Section(header: Text("Family"), footer: footerMessage) {
            if let family = currentFamily {
                VStack(alignment: .leading, spacing: 12) {
                    familyDetailRow(title: "Family Name", value: family.name)
                    if let joinCode = family.joinCode {
                        familyDetailRow(title: "Join Code", value: joinCode, monospaced: true)
                    }
                    familyDetailRow(title: "Linked Students", value: "\(signInManager.students.count)")
                }
            } else {
                Button {
                    showingCreateFamily = true
                } label: {
                    Label("Create New Family", systemImage: "plus.circle.fill")
                }
                
                Button {
                    showingJoinFamily = true
                } label: {
                    Label("Join Existing Family", systemImage: "person.2.badge.plus")
                }
            }
        }
    }
    
    private var footerMessage: some View {
        Group {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else if signInManager.isOffline {
                Text("Offline mode – changes will sync when you're back online.")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func familyDetailRow(title: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .padding(.horizontal, monospaced ? 12 : 0)
                .padding(.vertical, monospaced ? 6 : 0)
                .background(monospaced ? Color.gray.opacity(0.1) : Color.clear)
                .cornerRadius(8)
        }
    }
    
    // MARK: - Create Family Sheet
    
    private var createFamilySheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Create New Family")) {
                    TextField("Family Name", text: $newFamilyName)
                }
            }
            .navigationTitle("Create Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCreateFamily = false
                        newFamilyName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await performCreateFamily() }
                    }
                    .disabled(newFamilyName.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private var joinFamilySheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Join Family")) {
                    TextField("Enter Join Code", text: $joinCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Join Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingJoinFamily = false
                        joinCode = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        Task { await performJoinFamily() }
                    }
                    .disabled(joinCode.trimmingCharacters(in: .whitespaces).count < 6 || isSubmitting)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func performCreateFamily() async {
        guard isParent else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await signInManager.createFamily(named: newFamilyName.trimmingCharacters(in: .whitespacesAndNewlines))
            await MainActor.run {
                showingCreateFamily = false
                newFamilyName = ""
                errorMessage = nil
            }
        } catch let error as AppleSignInManager.FamilyJoinError {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func performJoinFamily() async {
        guard isParent else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await signInManager.joinFamily(with: joinCode)
            await MainActor.run {
                showingJoinFamily = false
                joinCode = ""
                errorMessage = nil
            }
        } catch let error as AppleSignInManager.FamilyJoinError {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}
