//
//  Reading.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/10/25.
//
import SwiftData
import Foundation

@Model
final class Reading: Assignment {
    @Attribute var startPage: Int?
    @Attribute var endPage: Int?
    @Attribute var resource: String?
    
    init(name: String, dueDate: Date, startPage: Int, endPage: Int, resource: String) {
        self.startPage = startPage
        self.endPage = endPage
        self.resource = resource
        super.init(name: name, dueDate: dueDate)
    }
}
