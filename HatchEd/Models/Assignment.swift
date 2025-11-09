//
//  Assignment.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//

import Foundation

struct Assignment: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var dueDate: Date?
    var instructions: String?
    var grade: Double?
    var subject: Subject?
    var questions: [Question]

    init(id: UUID = UUID(), title: String, dueDate: Date? = nil, instructions: String? = nil, grade: Double? = nil, subject: Subject? = nil, questions: [Question] = []) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.instructions = instructions
        self.grade = grade
        self.subject = subject
        self.questions = questions
    }
}
