//
//  Course.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//

import Foundation

struct Course: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var assignments: [Assignment]
    var grade: Double?
    var student: User
    var createdAt: Date?
    var updatedAt: Date?

    init(id: String = UUID().uuidString, name: String, assignments: [Assignment] = [], grade: Double? = nil, student: User, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.assignments = assignments
        self.grade = grade
        self.student = student
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
