//
//  HatchEdApp.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//  Added Apple Auth using ChatGPT

import SwiftUI
import SwiftData

@main
struct HatchEdApp: App {
    @StateObject private var authVM = AuthViewModel()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            UserData.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(.init())
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.user != nil {
                    DashboardView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authVM)
            .modelContainer(sharedModelContainer)
        }
    }
}

//  TODO:
//  Once my Apple Developer enrollment completes, I need to:

//  Set the correct Team in Xcode.
//  Enable iCloud/CloudKit in Signing & Capabilities.
//  Test Apple Sign-In on a real device.
