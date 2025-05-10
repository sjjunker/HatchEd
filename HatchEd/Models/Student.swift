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
    @Attribute var courses: [Course]?
    @Relationship var parent: Parent?

    init(name: String) {
        self.name = name
    }
}
