//
//  Assignment.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/10/25.
//
import SwiftData
import Foundation

@Model
class Assignment: Identifiable {
    @Attribute var id: UUID?
    @Attribute var name: String?
    @Attribute var dueDate: Date?
    @Attribute var pointsPossible: Int?
    @Attribute var pointsEarned: Int?
    @Attribute var grade: Double?
    @Relationship var lesson: Lesson?
    
    //Quiz Variables
    @Relationship(deleteRule: .cascade, inverse: \Question.assignment)
    var questions: [Question] = []
    
    //Reading Variables
    @Attribute var startPage: Int?
    @Attribute var endPage: Int?
    @Attribute var resource: String?

    //For Quiz Assignments
    init(name: String, dueDate: Date, pointsPossible: Int, pointsEarned: Int?, grade: Double?, questions: [Question]?) {
        self.id = UUID()
        self.name = name
        self.dueDate = dueDate
        self.pointsPossible = pointsPossible
        self.pointsEarned = pointsEarned
        self.grade = grade
    }
    
    //For Reading Assignments
    init(name: String, dueDate: Date, pointsPossible: Int, pointsEarned: Int?, grade: Double?, startPage: Int?, endPage: Int?, resource: String?) {
        self.id = UUID()
        self.name = name
        self.dueDate = dueDate
        self.pointsPossible = pointsPossible
        self.pointsEarned = pointsEarned
        self.grade = grade
        self.startPage = startPage
        self.endPage = endPage
        self.resource = resource
    }
    
    func calculateGrade() {
        if (pointsEarned != nil && pointsPossible! > 0) {
            self.grade = Double(pointsEarned!) / Double(pointsPossible!) * 100
        }
    }
}
