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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(task.color)
                .frame(width: 12, height: 12)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(formatter.string(from: task.startDate))
                    Text("•")
                    Text(durationString)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
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
