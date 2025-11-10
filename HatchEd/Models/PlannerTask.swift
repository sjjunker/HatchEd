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
