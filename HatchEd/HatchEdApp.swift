//
//  HatchEdApp.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//  Added Apple Auth using ChatGPT

//
//  HatchEdApp.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//

import SwiftUI
import SwiftData

@main
struct HatchEdApp: App {
    @StateObject private var signInManager = AppleSignInManager()

    // MARK: - ModelContainer setup for Parent and Child
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Parent.self,
            Student.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(.init()) // using private CloudKit DB
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
                if (signInManager.currentParent != nil) {
                    ParentDashboard()
                } else {
                    LoginView()
                }
            }
            .environmentObject(signInManager)
            .modelContainer(sharedModelContainer)
        }
    }
}





//  TODO:
//  Once my Apple Developer enrollment completes, I need to:

//  Set the correct Team in Xcode.
//  Enable iCloud/CloudKit in Signing & Capabilities.
//  Test Apple Sign-In on a real device.
