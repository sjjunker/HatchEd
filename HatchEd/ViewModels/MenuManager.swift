//
//  MenuManager.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/4/25.
//

import Foundation
import SwiftUI

@MainActor
class MenuManager: ObservableObject {
    @Published var menuItems: [NavigationDestination] = []
    
    let parentMenuItems: [NavigationDestination] = [
        .dashboard,
        .planner,
        .studentList,
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
        if user.role == "parent" {
            self.menuItems = parentMenuItems
        } else if user.role == "student" {
            self.menuItems = studentMenuItems
        } else {
            self.menuItems = []
        }
    }
}
