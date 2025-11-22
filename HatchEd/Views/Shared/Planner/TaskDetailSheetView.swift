//
//  TaskDetailSheetView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct TaskDetailSheetView: View {
    let task: PlannerTask
    let assignment: Assignment?
    @Environment(\.dismiss) private var dismiss
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with color indicator
                    HStack(alignment: .top, spacing: 16) {
                        Circle()
                            .fill(task.color)
                            .frame(width: 20, height: 20)
                            .padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(task.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.hatchEdText)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.hatchEdCardBackground)
                    )
                    
                    // Task Type Badge
                    if assignment != nil {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.hatchEdWarning)
                            Text("Assignment")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.hatchEdWarning)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.hatchEdWarning.opacity(0.15))
                        )
                    } else {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.hatchEdAccent)
                            Text("Planner Task")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.hatchEdAccent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.hatchEdAccent.opacity(0.15))
                        )
                    }
                    
                    // Time Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time Information")
                            .font(.headline)
                            .foregroundColor(.hatchEdText)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.hatchEdAccent)
                                    Text("Start Time")
                                        .font(.subheadline)
                                        .foregroundColor(.hatchEdSecondaryText)
                                }
                                Text(timeFormatter.string(from: task.startDate))
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.hatchEdText)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack {
                                    Image(systemName: "hourglass")
                                        .foregroundColor(.hatchEdAccent)
                                    Text("Duration")
                                        .font(.subheadline)
                                        .foregroundColor(.hatchEdSecondaryText)
                                }
                                Text(durationString)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.hatchEdText)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.hatchEdCardBackground)
                    )
                    
                    // Assignment-specific information
                    if let assignment = assignment {
                        // Due Date
                        if let dueDate = assignment.dueDate {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Due Date")
                                    .font(.headline)
                                    .foregroundColor(.hatchEdText)
                                
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundColor(.hatchEdWarning)
                                    Text(dateFormatter.string(from: dueDate))
                                        .font(.body)
                                        .foregroundColor(.hatchEdText)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.hatchEdCardBackground)
                            )
                        }
                        
                        // Grade
                        if let pointsAwarded = assignment.pointsAwarded,
                           let pointsPossible = assignment.pointsPossible,
                           pointsPossible > 0 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Grade")
                                    .font(.headline)
                                    .foregroundColor(.hatchEdText)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.hatchEdSuccess)
                                        Text(String(format: "%.0f / %.0f points", pointsAwarded, pointsPossible))
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.hatchEdText)
                                    }
                                    
                                    if let percentage = calculatePercentage(pointsAwarded: pointsAwarded, pointsPossible: pointsPossible) {
                                        Text(String(format: "%.1f%%", percentage))
                                            .font(.subheadline)
                                            .foregroundColor(.hatchEdSecondaryText)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.hatchEdCardBackground)
                            )
                        }
                        
                        // Instructions
                        if let instructions = assignment.instructions, !instructions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Instructions")
                                    .font(.headline)
                                    .foregroundColor(.hatchEdText)
                                
                                Text(instructions)
                                    .font(.body)
                                    .foregroundColor(.hatchEdText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.hatchEdCardBackground)
                            )
                        }
                    }
                    
                    // Date Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Date")
                            .font(.headline)
                            .foregroundColor(.hatchEdText)
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.hatchEdAccent)
                            Text(dateFormatter.string(from: task.startDate))
                                .font(.body)
                                .foregroundColor(.hatchEdText)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.hatchEdCardBackground)
                    )
                }
                .padding()
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(Color.hatchEdBackground)
        }
    }
    
    private var durationString: String {
        let hours = task.durationMinutes / 60
        let minutes = task.durationMinutes % 60
        if hours > 0 {
            return minutes == 0 ? "\(hours) hr" : "\(hours) hr \(minutes) min"
        }
        return "\(minutes) min"
    }
    
    private func calculatePercentage(pointsAwarded: Double, pointsPossible: Double) -> Double? {
        guard pointsPossible > 0 else { return nil }
        return (pointsAwarded / pointsPossible) * 100
    }
}

#Preview {
    TaskDetailSheetView(
        task: PlannerTask(
            id: "1",
            title: "Math Homework",
            startDate: Date(),
            durationMinutes: 90,
            colorName: "Blue"
        ),
        assignment: nil
    )
}

