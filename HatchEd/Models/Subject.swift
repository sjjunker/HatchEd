//
//  Subject.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import Foundation

struct Subject: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var createdAt: Date?
    var updatedAt: Date?

    init(id: String = UUID().uuidString, name: String, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
