//
//  Question.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//

import Foundation

struct Question: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var correctAnswer: String?
    var choices: [String]
    var isCorrect: Bool?

    init(id: UUID = UUID(), text: String, correctAnswer: String? = nil, choices: [String] = [], isCorrect: Bool? = nil) {
        self.id = id
        self.text = text
        self.correctAnswer = correctAnswer
        self.choices = choices
        self.isCorrect = isCorrect
    }
}
