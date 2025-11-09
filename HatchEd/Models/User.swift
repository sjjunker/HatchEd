//
//  UserProfile.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: String
    var appleId: String?
    var name: String?
    var email: String?
    var role: String?
    var familyId: String?
    var createdAt: Date?
    var updatedAt: Date?

    var isParent: Bool { role == "parent" }
    var isStudent: Bool { role == "student" }
    var requiresFamily: Bool { isStudent && familyId == nil }
}
