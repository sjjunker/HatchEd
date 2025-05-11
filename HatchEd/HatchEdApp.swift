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
            Assignment.self,
            Course.self,
            Lesson.self,
            Parent.self,
            Question.self,
            Student.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(.init("iCloud.HatchEd")) // using private CloudKit DB
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
                if let currentParent = signInManager.currentParent {
                    ParentDashboard()
                        .environmentObject(signInManager)
                        .modelContainer(sharedModelContainer)
                } else {
                    LoginView()
                        .environmentObject(signInManager)
                        .modelContainer(sharedModelContainer)
                }
            }
        }
    }
}

