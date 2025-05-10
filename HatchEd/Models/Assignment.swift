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

    init(name: String, dueDate: Date, pointsPossible: Int) {
        self.id = UUID()
        self.name = name
        self.dueDate = dueDate
        self.pointsPossible = pointsPossible
    }
    
    func calculateGrade() -> Double {
        guard let pointsPossible = pointsPossible, let pointsEarned = pointsEarned else {
            return 0.0
        }
        return Double(pointsEarned) / Double(pointsPossible) * 100
    }
}
