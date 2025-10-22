//
//  ChildDashboard.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//
import SwiftUI

struct StudentDashboard: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var signInManager: AppleSignInManager
    
    var body: some View {
        VStack {
            Text("Welcome, \(signInManager.currentUser?.name ?? "Child")!")
                .font(.largeTitle)
            // Other child-related content
        }
        .onAppear {
            // Load data specific to the child user
        }
    }
}

