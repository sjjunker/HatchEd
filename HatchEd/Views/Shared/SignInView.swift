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
    @EnvironmentObject var signInManager: AppleSignInManager
    
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
                    signInManager.handleSignIn(result: result)
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
            
            signInManager.handleGoogleSignIn(
                idToken: idToken,
                fullName: fullName,
                email: email
            )
        }
    }
}


