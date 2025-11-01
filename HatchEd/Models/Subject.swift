//
//  Subject.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//
import Foundation
import SwiftData

@Model
class Subject: Identifiable {
    var id: UUID?
    var name: String?
    
    init(id: UUID, name: String) {
        self.id = UUID()
        self.name = name
    }
}
