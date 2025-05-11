//
//  Question.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/10/25.
//
import SwiftData
import Foundation

@Model
final class Question: Identifiable {
    @Attribute var id: UUID?
    @Attribute var questionText: String?
    @Attribute var questionSelection: [String]?
    @Attribute var correctIndex: Int?
    @Attribute var guessedCorrectly: Bool?
    
    @Relationship var assignment: Assignment?
    
    init(questionText: String, questionSelection: [String], correctIndex: Int) {
        self.id = UUID()
        self.questionText = questionText
        self.questionSelection = questionSelection
        self.correctIndex = correctIndex
    }
    
    func checkAnswer(_ selectedIndex: Int) {
        guessedCorrectly = (selectedIndex == correctIndex!)
    }
}
