//
//  Course.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//

import Foundation
import SwiftData

@Model
class Course: Identifiable {
    @Attribute(.unique) var id: UUID?
    var name: String?
    var assignments: [Assignment]?
    var grade: Double?
    var subject: Subject?
    
    init(id: UUID, name: String, grade: Double? = nil, subject: Subject) {
        self.id = UUID()
        self.name = name
        self.grade = grade
        self.subject = subject
    }
}
