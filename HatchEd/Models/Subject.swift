//
//  Subject.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//
import Foundation

struct Subject: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
