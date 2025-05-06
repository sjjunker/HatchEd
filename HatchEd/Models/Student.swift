//
//  Student.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//
import SwiftData
import Foundation

@Model
class Student {
    @Attribute var name: String
    @Relationship var parent: Parent?

    init(name: String) {
        self.name = name
    }
}
