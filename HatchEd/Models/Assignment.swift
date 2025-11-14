//
//  Assignment.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//

import Foundation

struct Assignment: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var dueDate: Date?
    var instructions: String?
    var grade: Double?
    var subject: Subject?
    var questions: [Question]
    var createdAt: Date?
    var updatedAt: Date?

    init(id: String = UUID().uuidString, title: String, dueDate: Date? = nil, instructions: String? = nil, grade: Double? = nil, subject: Subject? = nil, questions: [Question] = [], createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.instructions = instructions
        self.grade = grade
        self.subject = subject
        self.questions = questions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
