//
//  UserProfile.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import SwiftData
import Foundation

@Model
class UserProfile {
    var id: String       // Apple user identifier (from AppleIDCredential)
    var name: String?
    var role: UserRole
    var familyID: UUID   // Links parents and children
    
    init(id: String, name: String?, role: UserRole, familyID: UUID) {
        self.id = id
        self.name = name
        self.role = role
        self.familyID = familyID
    }
}
