//
//  MockModelContext.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/10/25.
//
import SwiftData

extension ModelContext {
    static var preview: ModelContext {
        do {
            let schema = Schema([Assignment.self,
                                 Course.self,
                                 Lesson.self,
                                 Parent.self,
                                 Question.self,
                                 Student.self,])
            let container = try ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            ])
            return ModelContext(container)
        } catch {
            fatalError("❌ Failed to create preview model context: \(error)")
        }
    }
}

