//
//  Course.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//

import Foundation

struct Course: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var assignments: [Assignment]
    var grade: Double?
    var students: [User]
    var createdAt: Date?
    var updatedAt: Date?

    /// First student in the list (for backward compatibility where a single student is expected).
    var student: User {
        students.first ?? User(id: "", appleId: nil, googleId: nil, username: nil, name: nil, email: nil, role: nil, familyId: nil, invitePending: nil, inviteLink: nil, inviteToken: nil, createdAt: nil, updatedAt: nil)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, assignments, grade, createdAt, updatedAt
        case students
        case student
    }

    init(id: String = UUID().uuidString, name: String, assignments: [Assignment] = [], grade: Double? = nil, students: [User], createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.assignments = assignments
        self.grade = grade
        self.students = students
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        assignments = try c.decodeIfPresent([Assignment].self, forKey: .assignments) ?? []
        grade = try c.decodeIfPresent(Double.self, forKey: .grade)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        if let list = try c.decodeIfPresent([User].self, forKey: .students), !list.isEmpty {
            students = list
        } else if let single = try c.decodeIfPresent(User.self, forKey: .student) {
            students = [single]
        } else {
            students = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(assignments, forKey: .assignments)
        try c.encode(grade, forKey: .grade)
        try c.encode(students, forKey: .students)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}
