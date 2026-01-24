//
//  UsernamePasswordSignInView.swift
//  HatchEd
//
//  Created with assistance from Cursor (ChatGPT)
//

import SwiftUI

struct UsernamePasswordSignInView: View {
    @EnvironmentObject var signInManager: AppleSignInManager
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSignUp = false
    @State private var requiresTwoFactor = false
    @State private var twoFactorCode = ""
    @State private var tempUserId: String?
    
    var body: some View {
        VStack(spacing: 24) {
            if showSignUp {
                UsernamePasswordSignUpView(showSignUp: $showSignUp)
            } else {
                signInForm
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hatchEdBackground)
    }
    
    private var signInForm: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Sign In")
                    .font(.largeTitle.bold())
                    .foregroundColor(.hatchEdText)
                
                Text("Enter your username and password")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
            }
            
            VStack(spacing: 16) {
                if !requiresTwoFactor {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter your 6-digit verification code")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdSecondaryText)
                        
                        TextField("000000", text: $twoFactorCode)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .onChange(of: twoFactorCode) { oldValue, newValue in
                                // Limit to 6 digits
                                if newValue.count > 6 {
                                    twoFactorCode = String(newValue.prefix(6))
                                }
                            }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button(action: {
                    Task {
                        await signIn()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text(requiresTwoFactor ? "Verify" : "Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(Color.hatchEdAccent)
                .cornerRadius(12)
                .disabled(isLoading || (requiresTwoFactor ? twoFactorCode.count != 6 : (username.isEmpty || password.isEmpty)))
                
                if requiresTwoFactor {
                    Button(action: {
                        requiresTwoFactor = false
                        twoFactorCode = ""
                        errorMessage = nil
                    }) {
                        Text("Back")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdAccent)
                    }
                }
                
                Button(action: {
                    showSignUp = true
                }) {
                    Text("Don't have an account? Sign Up")
                        .font(.subheadline)
                        .foregroundColor(.hatchEdAccent)
                }
            }
        }
        .padding()
    }
    
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if requiresTwoFactor {
                try await signInManager.handleUsernamePasswordSignIn(
                    username: username,
                    password: password,
                    twoFactorCode: twoFactorCode
                )
            } else {
                try await signInManager.handleUsernamePasswordSignIn(
                    username: username,
                    password: password
                )
            }
        } catch let error as TwoFactorRequiredError {
            requiresTwoFactor = true
            tempUserId = error.userId
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct UsernamePasswordSignUpView: View {
    @EnvironmentObject var signInManager: AppleSignInManager
    @Binding var showSignUp: Bool
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var email = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Sign Up")
                        .font(.largeTitle.bold())
                        .foregroundColor(.hatchEdText)
                    
                    Text("Create a new account")
                        .font(.subheadline)
                        .foregroundColor(.hatchEdSecondaryText)
                }
                
                VStack(spacing: 16) {
                    TextField("Name (optional)", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)
                    
                    TextField("Email (optional)", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                    
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button(action: {
                        Task {
                            await signUp()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text("Sign Up")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .background(Color.hatchEdAccent)
                    .cornerRadius(12)
                    .disabled(isLoading || !isFormValid)
                    
                    Button(action: {
                        showSignUp = false
                    }) {
                        Text("Already have an account? Sign In")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdAccent)
                    }
                }
            }
            .padding()
        }
    }
    
    private var isFormValid: Bool {
        !username.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 6 &&
        username.count >= 3
    }
    
    private func signUp() async {
        isLoading = true
        errorMessage = nil
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            isLoading = false
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            isLoading = false
            return
        }
        
        guard username.count >= 3 else {
            errorMessage = "Username must be at least 3 characters"
            isLoading = false
            return
        }
        
        do {
            try await signInManager.handleUsernamePasswordSignUp(
                username: username,
                password: password,
                email: email.isEmpty ? nil : email,
                name: name.isEmpty ? nil : name
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

