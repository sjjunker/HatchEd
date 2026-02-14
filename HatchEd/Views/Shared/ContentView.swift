//
//  ContentView.swift
//  HatchEd
//
//  MVVM: Root view – binds to AuthViewModel and selects screen by sign-in state and role.
//
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showRequiredSignInSetup = false

    var body: some View {
        Group {
            if let token = authViewModel.pendingInviteToken {
                AcceptInviteView(token: token)
            } else {
                mainContent
            }
        }
        .fullScreenCover(isPresented: $showRequiredSignInSetup) {
            RequiredSignInSetupView(onComplete: { showRequiredSignInSetup = false })
                .environmentObject(authViewModel)
                .interactiveDismissDisabled(true)
        }
        .onAppear {
            if authViewModel.signInState == .signedIn && authViewModel.needsSignInMethod {
                showRequiredSignInSetup = true
            }
        }
        .onChange(of: authViewModel.signInState) { _, new in
            if new == .signedIn && authViewModel.needsSignInMethod {
                showRequiredSignInSetup = true
            }
        }
        .onChange(of: authViewModel.currentUser?.id) { _, _ in
            if authViewModel.signInState == .signedIn && authViewModel.needsSignInMethod {
                showRequiredSignInSetup = true
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch authViewModel.signInState {
            case .notSignedIn:
                SignInView()
            case .needsRoleSelection:
                if let userID = authViewModel.currentUser?.id {
                    RoleSelectionView(userID: userID)
                } else {
                    SignInView()
                }
            case .signedIn:
                dashboardView
            }
        }
    }

    @ViewBuilder
    private var dashboardView: some View {
        if let role = authViewModel.userRole {
            switch role {
            case "parent":
                ParentDashboard()
            case "student":
                StudentDashboard()
            default:
                if let userID = authViewModel.currentUser?.id {
                    RoleSelectionView(userID: userID)
                } else {
                    SignInView()
                }
            }
        } else if let userID = authViewModel.currentUser?.id {
            RoleSelectionView(userID: userID)
        } else {
            SignInView()
        }
    }
}

