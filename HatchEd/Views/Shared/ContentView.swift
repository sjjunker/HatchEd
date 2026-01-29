//
//  ContentView.swift
//  HatchEd
//
//  MVVM: Root view – binds to AuthViewModel and selects screen by sign-in state and role.
//
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
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
                if authViewModel.studentRequiresFamily {
                    StudentJoinFamilyView()
                } else {
                    StudentDashboard()
                }
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

