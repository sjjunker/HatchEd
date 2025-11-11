//
//  Subject.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import Foundation

struct Subject: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
