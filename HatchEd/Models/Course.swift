//
//  Course.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/10/25.
//
import SwiftData
import Foundation

@Model
class Course: Identifiable {
    @Attribute var id: UUID?
    @Attribute var name: String?
    @Attribute var resource: String?
    @Relationship var student: Student?

    @Relationship(deleteRule: .cascade, inverse: \Lesson.course)
    var lessons: [Lesson] = []

    init(name: String, resource: String) {
        self.id = UUID()
        self.name = name
        self.resource = resource
    }
}
