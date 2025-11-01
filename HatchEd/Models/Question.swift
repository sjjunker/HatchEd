//
//  Question.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//

import Foundation
import SwiftData

@Model
class Question: Identifiable {
    @Attribute(.unique) var id: UUID
    var text: String?
    var correctAnswer: String?
    var choices: [String]?
    var isCorrect: Bool?
    
    init(id: UUID, text: String? = nil, correctAnswer: String? = nil, choices: [String]? = nil, isCorrect: Bool? = nil) {
        self.id = UUID()
        self.text = text
        self.correctAnswer = correctAnswer
        self.choices = choices
        self.isCorrect = isCorrect
    }
}
