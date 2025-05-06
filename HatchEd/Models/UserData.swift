//
//  UserData.swift
//  HatchEd
//
//  Created by Sandi Junker using ChatGPT on 5/6/25.
//
import Foundation
import SwiftData

@Model
class UserData {
    @Attribute(.unique) var id: String
    var name: String?
    var joinedAt: Date

    init(id: String, name: String?, joinedAt: Date = .now) {
        self.id = id
        self.name = name
        self.joinedAt = joinedAt
    }
}

