//
//  UserData.swift
//  HatchEd
//
//  Created by Sandi Junker using ChatGPT on 5/6/25.
//
import Foundation
import SwiftData

@Model
class Parent {
    @Attribute var name: String?
    @Attribute var email: String?
    @Attribute var appleID: String?
    @Relationship(deleteRule: .cascade, inverse: \Student.parent) var students: [Student] = []

    init(name: String, email: String, appleID: String) {
        self.name = name
        self.email = email
        self.appleID = appleID
    }
}
