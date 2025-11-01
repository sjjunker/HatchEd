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
    
    @Attribute(.unique) var id: String       // Apple user identifier (from AppleIDCredential)
    var name: String?
    var email: String?
    var role: String?
    var familyID: String?  // Links parents and children
    
    //For students only
    var subjects: [Subject]?
    var courses: [Course]?
    var assignments: [Assignment]?
    
    init(id: String, name: String?, email: String?) {
        self.id = id
        self.name = name
        self.email = email
    }
}
