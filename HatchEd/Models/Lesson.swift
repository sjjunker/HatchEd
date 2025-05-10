//
//  Lesson.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/10/25.
//
import SwiftData
import Foundation

@Model
class Lesson: Identifiable {
    @Attribute var id: UUID?
    @Attribute var name: String?
    @Attribute var resource: String?
    @Attribute var assignments: [Assignment]?

    init(name: String, resource: String, assignments: [Assignment]?) {
        self.id = UUID()
        self.name = name
        self.resource = resource
        self.assignments = assignments
    }
}
