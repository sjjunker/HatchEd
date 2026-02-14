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
    var invitePending: Bool?
    /// Invite link for the child (only present when listing family students and invite is pending). Parent can copy and share later.
    var inviteLink: String?
    /// Invite token for app link (hatched://invite?token=...). Only present when invite is pending.
    var inviteToken: String?
    var createdAt: Date?
    var updatedAt: Date?

    var isParent: Bool { role == "parent" }
    var isStudent: Bool { role == "student" }
    var requiresFamily: Bool { isStudent && familyId == nil }
}
