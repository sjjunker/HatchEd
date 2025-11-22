//
//  AddTaskView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss

    let initialDate: Date
    let assignments: [Assignment]
    let existingTaskIds: Set<String>
    let onSave: (PlannerTask) -> Void

    @State private var title: String = ""
    @State private var date: Date
    @State private var durationMinutes: Int = 60
    @State private var selectedColorName: String = PlannerTask.colorOptions.first?.name ?? "Blue"
    @State private var selectedAssignment: Assignment?
    @State private var taskMode: TaskMode = .new

    enum TaskMode {
        case new
        case fromAssignment
    }

    init(initialDate: Date, assignments: [Assignment] = [], existingTaskIds: Set<String> = [], onSave: @escaping (PlannerTask) -> Void) {
        self.initialDate = initialDate
        self.assignments = assignments
        self.existingTaskIds = existingTaskIds
        self.onSave = onSave
        _date = State(initialValue: initialDate)
    }
    
    private var availableAssignments: [Assignment] {
        assignments.filter { assignment in
            // Filter out assignments that are already on the planner
            !existingTaskIds.contains("assignment-\(assignment.id)")
        }
    }

    var body: some View {
        NavigationView {
            Form {
                if !availableAssignments.isEmpty {
                    Section(header: Text("Add from Assignment")) {
                        Picker("Select Assignment", selection: $selectedAssignment) {
                            Text("Create New Task").tag(nil as Assignment?)
                            ForEach(availableAssignments) { assignment in
                                HStack {
                                    Text(assignment.title)
                                    if let dueDate = assignment.dueDate {
                                        Spacer()
                                        Text(dueDate, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tag(assignment as Assignment?)
                            }
                        }
                        .onChange(of: selectedAssignment) { newAssignment in
                            if let assignment = newAssignment {
                                taskMode = .fromAssignment
                                title = assignment.title
                                // Use assignment's due date and time, or initial date if no due date
                                if let dueDate = assignment.dueDate {
                                    date = dueDate
                                } else {
                                    date = initialDate
                                }
                                durationMinutes = 60 // Default duration
                            } else {
                                taskMode = .new
                                title = ""
                                date = initialDate
                            }
                        }
                    }
                }
                
                Section(header: Text("Task")) {
                    TextField("Title", text: $title)

                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Stepper(value: $durationMinutes, in: 15...480, step: 15) {
                        Text("Duration: \(formattedDuration)")
                    }
                }

                Section(header: Text("Color")) {
                    colorSelection
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.hatchEdAccent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.fraction(0.55), .large])
    }

    private var colorSelection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(PlannerTask.colorOptions, id: \.name) { option in
                Button {
                    selectedColorName = option.name
                } label: {
                    Circle()
                        .fill(option.color)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(selectedColorName == option.name ? 0.9 : 0), lineWidth: 3)
                        )
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .overlay(
                    Text(String(option.name.prefix(1)))
                        .font(.caption2)
                        .foregroundColor(.white)
                )
                .padding(4)
            }
        }
    }

    private var formattedDuration: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 {
            return minutes == 0 ? "\(hours) hr" : "\(hours) hr \(minutes) min"
        }
        return "\(minutes) min"
    }

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let task = PlannerTask(
            id: UUID().uuidString,
            title: trimmedTitle,
            startDate: date,
            durationMinutes: durationMinutes,
            colorName: selectedColorName
        )
        onSave(task)
        dismiss()
    }
}

#Preview {
    AddTaskView(initialDate: Date(), assignments: [], existingTaskIds: []) { _ in }
}
