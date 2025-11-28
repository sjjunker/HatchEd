//
//  ContentView.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var signInManager: AppleSignInManager
    
    var body: some View {
        Group {
            switch signInManager.signInState {
            case .notSignedIn:
                SignInView()
                    .onAppear {
                        print("[ContentView] Showing SignInView - signInState: notSignedIn")
                    }
            case .needsRoleSelection:
                if let userID = signInManager.currentUser?.id {
                    RoleSelectionView(userID: userID)
                        .onAppear {
                            print("[ContentView] Showing RoleSelectionView - userId: \(userID)")
                        }
                } else {
                    SignInView()
                        .onAppear {
                            print("[ContentView] Showing SignInView - userID is nil")
                        }
                }
            case .signedIn:
                signInManager.dashboardView
                    .onAppear {
                        print("[ContentView] Showing dashboard - role: \(signInManager.userRole ?? "nil"), hasUser: \(signInManager.currentUser != nil)")
                    }
            }
        }
        .onChange(of: signInManager.signInState) { oldValue, newValue in
            print("[ContentView] Sign-in state changed - from: \(oldValue), to: \(newValue), userRole: \(signInManager.userRole ?? "nil")")
        }
    }
}

