//
//  Settings.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/3/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
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
    @State private var showingTwoFactorSetup = false
    @State private var twoFactorEnabled = false
    
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
                        .foregroundColor(.hatchEdSecondaryText)
                }
                
                // Only show 2FA for username/password users
                if currentUser?.username != nil {
                    twoFactorSection
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
        .sheet(isPresented: $showingTwoFactorSetup) {
            TwoFactorSetupView(isPresented: $showingTwoFactorSetup, twoFactorEnabled: $twoFactorEnabled)
        }
        .onAppear {
            // Check if 2FA is enabled (would need to fetch from user model)
            // For now, we'll assume it's false and update when we add the field to User model
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
                        .foregroundColor(.hatchEdAccent)
                }
                
                Button {
                    showingJoinFamily = true
                } label: {
                    Label("Join Existing Family", systemImage: "person.2.badge.plus")
                        .foregroundColor(.hatchEdAccent)
                }
            }
        }
    }
    
    private var footerMessage: some View {
        Group {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.hatchEdCoralAccent)
            } else if signInManager.isOffline {
                Text("Offline mode – changes will sync when you're back online.")
                    .foregroundColor(.hatchEdWarning)
            }
        }
    }
    
    private func familyDetailRow(title: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.hatchEdSecondaryText)
            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .foregroundColor(.hatchEdText)
                .padding(.horizontal, monospaced ? 12 : 0)
                .padding(.vertical, monospaced ? 6 : 0)
                .background(monospaced ? Color.hatchEdAccentBackground : Color.clear)
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
    
    // MARK: - Two-Factor Authentication Section
    
    private var twoFactorSection: some View {
        Section(header: Text("Security"), footer: Text("Two-factor authentication adds an extra layer of security to your account.")) {
            if twoFactorEnabled {
                HStack {
                    Label("Two-Factor Authentication", systemImage: "checkmark.shield.fill")
                        .foregroundColor(.hatchEdSuccess)
                    Spacer()
                    Text("Enabled")
                        .foregroundColor(.hatchEdSecondaryText)
                }
                
                Button {
                    Task {
                        await disableTwoFactor()
                    }
                } label: {
                    Label("Disable Two-Factor Authentication", systemImage: "xmark.shield")
                        .foregroundColor(.hatchEdCoralAccent)
                }
            } else {
                Button {
                    showingTwoFactorSetup = true
                } label: {
                    Label("Enable Two-Factor Authentication", systemImage: "shield.fill")
                        .foregroundColor(.hatchEdAccent)
                }
            }
        }
    }
    
    private func disableTwoFactor() async {
        isSubmitting = true
        defer { isSubmitting = false }
        
        do {
            let api = APIClient.shared
            _ = try await api.disableTwoFactor(code: nil)
            await MainActor.run {
                twoFactorEnabled = false
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to disable two-factor authentication: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Two-Factor Setup View

struct TwoFactorSetupView: View {
    @EnvironmentObject private var signInManager: AppleSignInManager
    @Binding var isPresented: Bool
    @Binding var twoFactorEnabled: Bool
    @State private var qrCodeImage: UIImage?
    @State private var manualEntryKey: String = ""
    @State private var verificationCode: String = ""
    @State private var step: SetupStep = .scanning
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    enum SetupStep {
        case scanning
        case verifying
    }
    
    var body: some View {
        NavigationView {
            Form {
                switch step {
                case .scanning:
                    scanningStep
                case .verifying:
                    verifyingStep
                }
            }
            .navigationTitle("Set Up Two-Factor Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadQRCode()
            }
        }
    }
    
    private var scanningStep: some View {
        Section {
            VStack(spacing: 20) {
                Text("Scan this QR code with your authenticator app")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                
                if let qrCodeImage {
                    Image(uiImage: qrCodeImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                } else if isLoading {
                    ProgressView()
                        .frame(width: 250, height: 250)
                }
                
                if !manualEntryKey.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or enter this key manually:")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdSecondaryText)
                        Text(manualEntryKey)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.hatchEdAccentBackground)
                            .cornerRadius(8)
                    }
                    .padding()
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Button("I've scanned the code") {
                    step = .verifying
                }
                .buttonStyle(.borderedProminent)
                .disabled(qrCodeImage == nil)
            }
        }
    }
    
    private var verifyingStep: some View {
        Section {
            VStack(spacing: 20) {
                Text("Enter the 6-digit code from your authenticator app")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                
                TextField("000000", text: $verificationCode)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .onChange(of: verificationCode) { oldValue, newValue in
                        if newValue.count > 6 {
                            verificationCode = String(newValue.prefix(6))
                        }
                    }
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button("Verify and Enable") {
                    Task {
                        await verifyAndEnable()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(verificationCode.count != 6 || isLoading)
                
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
    
    private func loadQRCode() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let api = APIClient.shared
            let response = try await api.setupTwoFactor()
            
            await MainActor.run {
                // Decode QR code from base64 data URL (format: data:image/png;base64,...)
                let base64String = response.qrCode.contains(",") 
                    ? String(response.qrCode.split(separator: ",").last ?? "")
                    : response.qrCode
                
                if let data = Data(base64Encoded: base64String),
                   let image = UIImage(data: data) {
                    qrCodeImage = image
                }
                manualEntryKey = response.manualEntryKey
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load QR code: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func verifyAndEnable() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let api = APIClient.shared
            _ = try await api.verifyTwoFactor(code: verificationCode)
            
            await MainActor.run {
                twoFactorEnabled = true
                isPresented = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Invalid verification code. Please try again."
                isLoading = false
            }
        }
    }
}
