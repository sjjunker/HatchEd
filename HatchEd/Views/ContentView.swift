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
            case .needsRoleSelection:
                if let userID = signInManager.currentUser?.id {
                    RoleSelectionView(userID: userID)
                } else {
                    SignInView()
                }
            case .signedIn:
                signInManager.dashboardView
            }
        }
    }
}

