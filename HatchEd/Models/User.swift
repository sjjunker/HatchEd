//
//  UserProfile.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import Foundation

struct User: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var appleId: String?
    var googleId: String?
    var username: String?
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
