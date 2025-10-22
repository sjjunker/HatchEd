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

import SwiftUI
import SwiftData

@main
struct HatchEdApp: App {
    // 1️⃣ Create your SwiftData model container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([User.self])
        let config = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    // 2️⃣ Initialize your AppleSignInManager with that same context
    @StateObject private var signInManager: AppleSignInManager

    init() {
        let context = sharedModelContainer.mainContext
        _signInManager = StateObject(wrappedValue: AppleSignInManager(modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            SignInView()
                .environmentObject(signInManager)       // 👈 gives your SignInView access to the manager
                .modelContainer(sharedModelContainer)   // 👈 makes SwiftData available app-wide
        }
    }
}



