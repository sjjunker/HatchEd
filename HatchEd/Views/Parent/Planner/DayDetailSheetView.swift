//
//  DayDetailSheetView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct DayDetailSheetView: View {
    let date: Date
    let tasks: [PlannerTask]
    let onDelete: (PlannerTask) -> Void

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        return f
    }()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.hatchEdAccent)
                    Text(formatter.string(from: date))
                        .font(.title3.bold())
                        .foregroundColor(.hatchEdText)
                }
                .padding()

                if tasks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.hatchEdSecondaryText)
                        Text("No tasks scheduled for this day.")
                            .foregroundColor(.hatchEdSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(tasks) { task in
                                PlannerTaskRow(task: task)
                                    .padding(.horizontal)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            onDelete(task)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Day Overview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    DayDetailSheetView(date: Date(), tasks: [], onDelete: { _ in })
}
