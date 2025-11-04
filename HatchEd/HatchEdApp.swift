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
    // Create a shared model container once for the whole app
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([User.self, Subject.self, Assignment.self, Course.self, Question.self, Family.self])
        return try! ModelContainer(for: schema)
    }()

    // Pass its model context to your sign-in manager
    @StateObject private var signInManager = AppleSignInManager(
        modelContext: ModelContext(sharedModelContainer)
    )
    
    @StateObject private var menuManager = MenuManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(signInManager)
                .environmentObject(menuManager)
                .modelContainer(Self.sharedModelContainer) // makes it available to SwiftUI views
        }
    }
}




