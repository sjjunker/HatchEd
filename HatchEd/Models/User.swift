//
//  UserProfile.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import SwiftData
import Foundation

@Model
class User {
    var id: String       // Apple user identifier (from AppleIDCredential)
    var name: String?
    var email: String?
    var role: String?
    var students: [Student]?
    var familyID: String?  // Links parents and children
    
    init(id: String, name: String?, email: String?) {
        self.id = id
        self.name = name
        self.email = email
    }
}
