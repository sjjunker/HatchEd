//
//  Student.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//
import SwiftData
import Foundation

@Model
class Student: Identifiable {
    @Attribute var id: UUID?
    @Attribute var name: String?
    @Relationship(deleteRule: .cascade, inverse: \Course.student) var courses: [Course] = []
    @Relationship var parent: Parent?

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}
