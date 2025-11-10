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
    let onSave: (PlannerTask) -> Void

    @State private var title: String = ""
    @State private var date: Date
    @State private var durationMinutes: Int = 60
    @State private var selectedColorName: String = PlannerTask.colorOptions.first?.name ?? "Blue"

    init(initialDate: Date, onSave: @escaping (PlannerTask) -> Void) {
        self.initialDate = initialDate
        self.onSave = onSave
        _date = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationView {
            Form {
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
    AddTaskView(initialDate: Date()) { _ in }
}
