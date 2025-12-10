//
//  Assignment.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//

import Foundation

struct Assignment: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    var studentId: String
    var dueDate: Date?
    var instructions: String?
    var pointsPossible: Double?
    var pointsAwarded: Double?
    var questions: [Question]
    var completed: Bool
    var createdAt: Date?
    var updatedAt: Date?

    init(id: String = UUID().uuidString, title: String, studentId: String, dueDate: Date? = nil, instructions: String? = nil, pointsPossible: Double? = nil, pointsAwarded: Double? = nil, questions: [Question] = [], completed: Bool = false, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.studentId = studentId
        self.dueDate = dueDate
        self.instructions = instructions
        self.pointsPossible = pointsPossible
        self.pointsAwarded = pointsAwarded
        self.questions = questions
        self.completed = completed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Computed property: assignment is completed if it has points awarded or is explicitly marked complete
    var isCompleted: Bool {
        return completed || pointsAwarded != nil
    }
}
