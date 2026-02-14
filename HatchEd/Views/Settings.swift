//
//  Settings.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/3/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct Settings: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showingJoinFamily = false
    @State private var joinCode = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var showingTwoFactorSetup = false
    @State private var twoFactorEnabled = false
    @State private var studentToDelete: User?
    @State private var isDeletingStudent = false
    
    private var currentUser: User? {
        authViewModel.currentUser
    }
    
    private var isParent: Bool {
        currentUser?.role == "parent"
    }
    
    private var currentFamily: Family? {
        authViewModel.currentFamily
    }
    
    var body: some View {
        NavigationView {
            Form {
                if isParent {
                    familySection
                    studentsSection
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
        .sheet(isPresented: $showingJoinFamily) {
            joinFamilySheet
        }
        .sheet(isPresented: $showingTwoFactorSetup) {
            TwoFactorSetupView(isPresented: $showingTwoFactorSetup, twoFactorEnabled: $twoFactorEnabled)
        }
        .alert("Remove student?", isPresented: Binding(
            get: { studentToDelete != nil },
            set: { if !$0 { studentToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                studentToDelete = nil
            }
            Button("Remove", role: .destructive) {
                if let student = studentToDelete {
                    Task { await performDeleteChild(student) }
                }
                studentToDelete = nil
            }
        } message: {
            if let student = studentToDelete {
                Text("\(student.name ?? "This student") will no longer have access to this family. Their account will be removed. This cannot be undone.")
            }
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
                    familyDetailRow(title: "Linked Students", value: "\(authViewModel.students.count)")
                }
            } else {
                Text("A family is created for you when you sign in. If you don't see one, pull to refresh on the dashboard.")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                Button {
                    showingJoinFamily = true
                } label: {
                    Label("Join Existing Family", systemImage: "person.2.badge.plus")
                        .foregroundColor(.hatchEdAccent)
                }
            }
        }
    }
    
    // MARK: - Students Section (parents only)
    
    private var studentsSection: some View {
        Section(header: Text("Students"), footer: Text("Removing a student deletes their account. They will no longer be able to sign in or see family content.")) {
            ForEach(authViewModel.students) { student in
                HStack {
                    Text(student.name ?? "Student")
                        .foregroundColor(.hatchEdText)
                    Spacer()
                    Button(role: .destructive) {
                        studentToDelete = student
                    } label: {
                        Text("Remove")
                    }
                    .disabled(isDeletingStudent)
                }
            }
        }
    }
    
    private func performDeleteChild(_ student: User) async {
        isDeletingStudent = true
        errorMessage = nil
        defer { isDeletingStudent = false }
        do {
            try await APIClient.shared.deleteChild(childId: student.id)
            await MainActor.run {
                authViewModel.updateUserFromDatabase()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private var footerMessage: some View {
        Group {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.hatchEdCoralAccent)
            } else if authViewModel.isOffline {
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
    
    private func performJoinFamily() async {
        guard isParent else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await authViewModel.joinFamily(with: joinCode)
            await MainActor.run {
                showingJoinFamily = false
                joinCode = ""
                errorMessage = nil
            }
        } catch let error as AuthViewModel.FamilyJoinError {
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
    @EnvironmentObject private var authViewModel: AuthViewModel
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
            ScrollView {
                VStack(spacing: 24) {
                    // What is 2FA explanation
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.hatchEdAccent)
                                .font(.title2)
                            Text("What is Two-Factor Authentication?")
                                .font(.headline)
                        }
                        
                        Text("Two-factor authentication (2FA) adds an extra layer of security to your account. Instead of just using your password, you'll also need a code from an authenticator app on your phone.")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdSecondaryText)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.hatchEdAccentBackground.opacity(0.3))
                    .cornerRadius(12)
                    
                    // What is an authenticator app
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "app.badge")
                                .foregroundColor(.hatchEdAccent)
                                .font(.title2)
                            Text("What is an Authenticator App?")
                                .font(.headline)
                        }
                        
                        Text("An authenticator app generates time-based security codes on your phone. It works even without internet and provides codes that change every 30 seconds for maximum security.")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdSecondaryText)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.hatchEdAccentBackground.opacity(0.3))
                    .cornerRadius(12)
                    
                    // Download instructions
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.hatchEdAccent)
                                .font(.title2)
                            Text("Download an Authenticator App")
                                .font(.headline)
                        }
                        
                        Text("You'll need to download a free authenticator app on your phone. We recommend:")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdSecondaryText)
                            .padding(.bottom, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Link(destination: URL(string: "https://apps.apple.com/app/google-authenticator/id388497605")!) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.hatchEdSuccess)
                                    Text("Google Authenticator")
                                        .foregroundColor(.hatchEdAccent)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(.hatchEdSecondaryText)
                                        .font(.caption)
                                }
                            }
                            
                            Link(destination: URL(string: "https://apps.apple.com/app/microsoft-authenticator/id983156458")!) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.hatchEdSuccess)
                                    Text("Microsoft Authenticator")
                                        .foregroundColor(.hatchEdAccent)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(.hatchEdSecondaryText)
                                        .font(.caption)
                                }
                            }
                            
                            Link(destination: URL(string: "https://apps.apple.com/app/authy/id494168017")!) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.hatchEdSuccess)
                                    Text("Authy")
                                        .foregroundColor(.hatchEdAccent)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(.hatchEdSecondaryText)
                                        .font(.caption)
                                }
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.hatchEdAccentBackground.opacity(0.3))
                    .cornerRadius(12)
                    
                    Divider()
                    
                    // QR Code section
                    VStack(spacing: 16) {
                        Text("Step 1: Scan the QR Code")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text("Open your authenticator app and scan this QR code:")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdSecondaryText)
                            .multilineTextAlignment(.center)
                        
                        if let qrCodeImage {
                            Image(uiImage: qrCodeImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 250, height: 250)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                        } else if isLoading {
                            ProgressView()
                                .frame(width: 250, height: 250)
                        }
                        
                        if !manualEntryKey.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Can't scan? Enter this key manually:")
                                    .font(.subheadline)
                                    .foregroundColor(.hatchEdSecondaryText)
                                Text(manualEntryKey)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .background(Color.hatchEdAccentBackground)
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                            .padding()
                        }
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
                    .padding(.top, 8)
                }
                .padding()
            }
        }
    }
    
    private var verifyingStep: some View {
        Section {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Step 2: Enter Verification Code")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text("Open your authenticator app and enter the 6-digit code it displays. The code refreshes every 30 seconds.")
                        .font(.subheadline)
                        .foregroundColor(.hatchEdSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                TextField("000000", text: $verificationCode)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .onChange(of: verificationCode) { oldValue, newValue in
                        if newValue.count > 6 {
                            verificationCode = String(newValue.prefix(6))
                        }
                    }
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Button("Verify and Enable") {
                    Task {
                        await verifyAndEnable()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(verificationCode.count != 6 || isLoading)
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                }
                
                Button("Back") {
                    step = .scanning
                }
                .padding(.top, 8)
            }
            .padding()
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

// MARK: - Set username & password (for invite-only accounts)

struct SetUsernamePasswordSheet: View {
    let currentUsername: String?
    let onSave: (String?, String?) -> Void
    let onDismiss: () -> Void
    
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    
    private var needsUsername: Bool {
        (currentUsername ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                if needsUsername {
                    Section(header: Text("Username")) {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }
                Section(header: Text("Password"), footer: Text("At least 6 characters.")) {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    SecureField("Confirm password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.hatchEdCoralAccent)
                    }
                }
            }
            .navigationTitle("Set sign-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let u = username.trimmingCharacters(in: .whitespaces)
                        if needsUsername && u.isEmpty {
                            errorMessage = "Enter a username."
                            return
                        }
                        if password.count < 6 {
                            errorMessage = "Password must be at least 6 characters."
                            return
                        }
                        if password != confirmPassword {
                            errorMessage = "Passwords do not match."
                            return
                        }
                        errorMessage = nil
                        onSave(needsUsername ? u : nil, password)
                    }
                    .disabled(needsUsername && username.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || confirmPassword.isEmpty)
                }
            }
        }
    }
}
