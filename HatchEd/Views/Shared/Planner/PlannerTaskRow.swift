//
//  PlannerTaskRow.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct PlannerTaskRow: View {
    let task: PlannerTask

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var isAssignment: Bool {
        task.id.hasPrefix("assignment-")
    }

    private var isDueAssignment: Bool {
        task.id.hasPrefix("assignment-due-")
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isAssignment {
                Image(systemName: isDueAssignment ? "exclamationmark.circle.fill" : "doc.text.fill")
                    .font(.caption)
                    .foregroundColor(isDueAssignment ? .red : task.color)
                    .padding(.top, 6)
            } else {
                Circle()
                    .fill(task.color)
                    .frame(width: 12, height: 12)
                    .padding(.top, 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isAssignment {
                        Text(isDueAssignment ? "Due" : "Assignment")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isDueAssignment ? Color.red : task.color)
                            .cornerRadius(4)
                    }
                    Text(task.title)
                        .font(.headline)
                        .foregroundColor(.hatchEdText)
                }

                HStack(spacing: 8) {
                    Image(systemName: isDueAssignment ? "exclamationmark.triangle.fill" : (isAssignment ? "calendar" : "clock"))
                        .font(.caption2)
                        .foregroundColor(isDueAssignment ? .red : .hatchEdAccent)
                    Text(formatter.string(from: task.startDate))
                    Text("•")
                    Text(durationString)
                    if let subject = task.subject {
                        Text("•")
                        Text(subject)
                            .foregroundColor(.hatchEdAccent)
                    }
                }
                .font(.caption)
                .foregroundColor(.hatchEdSecondaryText)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isAssignment ? (isDueAssignment ? Color.red.opacity(0.6) : task.color.opacity(0.5)) : Color.clear, lineWidth: 2)
                )
                .shadow(color: (isDueAssignment ? Color.red : task.color).opacity(isAssignment ? 0.3 : 0.2), radius: 4, x: 0, y: 2)
        )
    }

    private var durationString: String {
        let hours = task.durationMinutes / 60
        let minutes = task.durationMinutes % 60
        if hours > 0 {
            return minutes == 0 ? "\(hours) hr" : "\(hours) hr \(minutes) min"
        }
        return "\(minutes) min"
    }
}

#Preview {
    PlannerTaskRow(task: PlannerTask(id: "1", title: "Demo", startDate: Date(), durationMinutes: 90, colorName: "Blue"))
}
