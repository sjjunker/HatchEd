//
//  MenuManager.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/4/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import Foundation
import SwiftUI

@MainActor
class MenuManager: ObservableObject {
    @Published var menuItems: [NavigationDestination] = []
    
    let parentMenuItems: [NavigationDestination] = [
        .dashboard,
        .planner,
        .subjects,
        .reportCard,
        .portfolio,
        .resources,
        .settings
    ]
    
    let studentMenuItems: [NavigationDestination] = [
        .dashboard,
        .planner,
        .reportCard,
        .portfolio,
        .resources,
        .settings
    ]
    
    func setMenuItems(user: User) {
        guard let role = user.role else {
            menuItems = []
            return
        }
        if role == "parent" {
            self.menuItems = parentMenuItems
        } else if role == "student" {
            self.menuItems = studentMenuItems
        } else {
            self.menuItems = []
        }
    }
}
