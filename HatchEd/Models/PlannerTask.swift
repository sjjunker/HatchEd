//
//  PlannerTask.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import Foundation
import SwiftUI

struct PlannerTask: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var startDate: Date
    var durationMinutes: Int
    var colorName: String
    var subject: String?
    var studentIds: [String]

    init(id: String = UUID().uuidString, title: String, startDate: Date, durationMinutes: Int, colorName: String, subject: String? = nil, studentIds: [String] = []) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.colorName = colorName
        self.subject = subject
        self.studentIds = studentIds
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case startDate
        case durationMinutes
        case colorName
        case subject
        case studentIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startDate = try container.decode(Date.self, forKey: .startDate)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        colorName = try container.decode(String.self, forKey: .colorName)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        studentIds = try container.decodeIfPresent([String].self, forKey: .studentIds) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(colorName, forKey: .colorName)
        try container.encodeIfPresent(subject, forKey: .subject)
        try container.encode(studentIds, forKey: .studentIds)
    }

    var color: Color {
        PlannerTask.color(for: colorName)
    }

    static func color(for name: String) -> Color {
        colorOptions.first(where: { $0.name == name })?.color ?? .blue
    }

    static let colorOptions: [(name: String, color: Color)] = [
        ("Blue", .systemBlue),
        ("Green", .systemGreen),
        ("Orange", .systemOrange),
        ("Pink", .systemPink),
        ("Purple", .systemIndigo),
        ("Red", .systemRed),
        ("Teal", .teal)
    ]
}

extension Color {
    static let systemBlue = Color(.systemBlue)
    static let systemGreen = Color(.systemGreen)
    static let systemOrange = Color(.systemOrange)
    static let systemPink = Color(.systemPink)
    static let systemIndigo = Color(.systemIndigo)
    static let systemRed = Color(.systemRed)
}
