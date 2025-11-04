//
//  Family.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/3/25.
//
import SwiftData
import Foundation

@Model
class Family {
    @Attribute(.unique) var id: String
    var name: String
    var joinCode: String
    @Relationship(deleteRule: .cascade) var members: [User] = []

    init(name: String) {
        self.id = UUID().uuidString
        self.name = name
        self.joinCode = Family.generateJoinCode()
    }

    static func generateJoinCode(length: Int = 6) -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
}

