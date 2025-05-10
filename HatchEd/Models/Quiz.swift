//
//  Quiz.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/10/25.
//
import SwiftData
import Foundation

@Model
final class Quiz: Assignment {
    @Attribute var questions: [Question]?
}
