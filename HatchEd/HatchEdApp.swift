//
//  HatchEdApp.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

@main
struct HatchEdApp: App {
    @StateObject private var signInManager = AppleSignInManager()
    @StateObject private var menuManager = MenuManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(signInManager)
                .environmentObject(menuManager)
                .background(Color.hatchEdBackground)
        }
    }
}




