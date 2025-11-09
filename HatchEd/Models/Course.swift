//
//  Course.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//

import Foundation

struct Course: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var assignments: [Assignment]
    var grade: Double?
    var subject: Subject?

    init(id: UUID = UUID(), name: String, assignments: [Assignment] = [], grade: Double? = nil, subject: Subject? = nil) {
        self.id = id
        self.name = name
        self.assignments = assignments
        self.grade = grade
        self.subject = subject
    }
}
