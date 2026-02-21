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
    let onSaveTask: (PlannerTask) -> Void

    @State private var title: String = ""
    @State private var date: Date
    @State private var durationMinutes: Int = 60
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    init(initialDate: Date, onSaveTask: @escaping (PlannerTask) -> Void) {
        self.initialDate = initialDate
        self.onSaveTask = onSaveTask
        _date = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)

                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    
                    Stepper(value: $durationMinutes, in: 15...480, step: 15) {
                        Text("Duration: \(formattedDuration)")
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
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
                        Task {
                            await saveTask()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.hatchEdAccent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.fraction(0.65), .large])
    }
    private var formattedDuration: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 {
            return minutes == 0 ? "\(hours) hr" : "\(hours) hr \(minutes) min"
        }
        return "\(minutes) min"
    }

    @MainActor
    private func saveTask() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Title is required"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            let task = try await APIClient.shared.createPlannerTask(
                title: trimmedTitle,
                startDate: date,
                durationMinutes: durationMinutes,
                colorName: "Blue",
                subject: nil
            )
            onSaveTask(task)
            dismiss()
        } catch {
            errorMessage = "Failed to create task: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

#Preview {
    AddTaskView(initialDate: Date(), onSaveTask: { _ in })
}
