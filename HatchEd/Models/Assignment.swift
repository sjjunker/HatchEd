//
//  Assignment.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/30/25.
//

import Foundation

struct Assignment: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    var studentId: String
    var workDates: [Date]
    var workDurationsMinutes: [Int]
    var dueDate: Date?
    var instructions: String?
    var pointsPossible: Double?
    var pointsAwarded: Double?
    var courseId: String?
    var questions: [Question]
    var completed: Bool
    /// Number of work sessions logged (0…number of work dates).
    var workSessionsCompleted: Int
    /// When true, each session unlocks only on or after its scheduled calendar day (UTC); when false, honor system.
    var strictWorkSessionProgress: Bool
    var createdAt: Date?
    var updatedAt: Date?

    init(id: String = UUID().uuidString, title: String, studentId: String, workDates: [Date] = [], workDurationsMinutes: [Int] = [], dueDate: Date? = nil, instructions: String? = nil, pointsPossible: Double? = nil, pointsAwarded: Double? = nil, courseId: String? = nil, questions: [Question] = [], completed: Bool = false, workSessionsCompleted: Int = 0, strictWorkSessionProgress: Bool = false, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.studentId = studentId
        self.workDates = workDates
        self.workDurationsMinutes = workDates.indices.map { index in
            let duration = index < workDurationsMinutes.count ? workDurationsMinutes[index] : 60
            return max(15, duration)
        }
        self.dueDate = dueDate
        self.instructions = instructions
        self.pointsPossible = pointsPossible
        self.pointsAwarded = pointsAwarded
        self.courseId = courseId
        self.questions = questions
        self.completed = completed
        self.workSessionsCompleted = max(0, workSessionsCompleted)
        self.strictWorkSessionProgress = strictWorkSessionProgress
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var workSessionTotal: Int { workDates.count }

    /// Whether the student may log another work session today (client hint; server enforces when strict).
    func mayIncrementWorkSession(calendar: Calendar = .current) -> Bool {
        guard workDates.count > 0, workSessionsCompleted < workDates.count else { return false }
        if !strictWorkSessionProgress { return true }
        let sorted = workDates.sorted()
        let today = calendar.startOfDay(for: Date())
        let required = calendar.startOfDay(for: sorted[workSessionsCompleted])
        return today >= required
    }
    
    // Computed property: assignment is completed if it has points awarded or is explicitly marked complete
    var isCompleted: Bool {
        return completed || pointsAwarded != nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case studentId
        case workDates
        case workDurationsMinutes
        case workDate
        case dueDate
        case instructions
        case pointsPossible
        case pointsAwarded
        case courseId
        case questions
        case completed
        case workSessionsCompleted
        case strictWorkSessionProgress
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        studentId = try container.decode(String.self, forKey: .studentId)
        workDates = try container.decodeIfPresent([Date].self, forKey: .workDates)
            ?? (try container.decodeIfPresent(Date.self, forKey: .workDate).map { [$0] } ?? [])
        let decodedDurations = try container.decodeIfPresent([Int].self, forKey: .workDurationsMinutes) ?? []
        workDurationsMinutes = workDates.indices.map { index in
            let duration = index < decodedDurations.count ? decodedDurations[index] : 60
            return max(15, duration)
        }
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions)
        pointsPossible = try container.decodeIfPresent(Double.self, forKey: .pointsPossible)
        pointsAwarded = try container.decodeIfPresent(Double.self, forKey: .pointsAwarded)
        courseId = try container.decodeIfPresent(String.self, forKey: .courseId)
        questions = try container.decodeIfPresent([Question].self, forKey: .questions) ?? []
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        workSessionsCompleted = max(0, try container.decodeIfPresent(Int.self, forKey: .workSessionsCompleted) ?? 0)
        strictWorkSessionProgress = try container.decodeIfPresent(Bool.self, forKey: .strictWorkSessionProgress) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(studentId, forKey: .studentId)
        try container.encode(workDates, forKey: .workDates)
        try container.encode(workDurationsMinutes, forKey: .workDurationsMinutes)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(instructions, forKey: .instructions)
        try container.encodeIfPresent(pointsPossible, forKey: .pointsPossible)
        try container.encodeIfPresent(pointsAwarded, forKey: .pointsAwarded)
        try container.encodeIfPresent(courseId, forKey: .courseId)
        try container.encode(questions, forKey: .questions)
        try container.encode(completed, forKey: .completed)
        try container.encode(workSessionsCompleted, forKey: .workSessionsCompleted)
        try container.encode(strictWorkSessionProgress, forKey: .strictWorkSessionProgress)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}
