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
    let students: [User]
    let existingTaskIds: Set<String>
    let onSaveTask: (PlannerTask) -> Void
    let onSaveAssignment: () -> Void

    @State private var title: String = ""
    @State private var date: Date
    @State private var durationMinutes: Int = 60
    @State private var selectedColorName: String = PlannerTask.colorOptions.first?.name ?? "Blue"
    @State private var selectedAssignment: Assignment?
    @State private var taskMode: TaskMode = .new
    @State private var selectedCourse: Course? = nil
    @State private var selectedStudent: User? = nil
    @State private var courses: [Course] = []
    @State private var isLoadingCourses: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    enum TaskMode {
        case new
        case fromAssignment
    }
    

    init(initialDate: Date, assignments: [Assignment] = [], students: [User] = [], existingTaskIds: Set<String> = [], onSaveTask: @escaping (PlannerTask) -> Void, onSaveAssignment: @escaping () -> Void) {
        self.initialDate = initialDate
        self.assignments = assignments
        self.students = students
        self.existingTaskIds = existingTaskIds
        self.onSaveTask = onSaveTask
        self.onSaveAssignment = onSaveAssignment
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
                
                // Show student selection first
                Section(header: Text("Student")) {
                    if !students.isEmpty {
                        Picker("Select Student", selection: $selectedStudent) {
                            Text("None").tag(nil as User?)
                            ForEach(students) { student in
                                Text(student.name ?? "Student").tag(student as User?)
                            }
                        }
                        .onChange(of: selectedStudent) { newStudent in
                            // Clear course selection when student changes
                            selectedCourse = nil
                        }
                    } else {
                        Text("No students available")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
                
                // Show course selection when student is selected
                if selectedStudent != nil {
                    Section(header: Text("Course")) {
                        courseSelection
                    }
                }

                Section(header: Text("Color")) {
                    colorSelection
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || (selectedCourse != nil && selectedStudent == nil))
                }
            }
        }
        .presentationDetents([.fraction(0.65), .large])
        .onAppear {
            Task {
                await loadCourses()
            }
        }
    }
    
    private var courseSelection: some View {
        VStack(spacing: 12) {
            if let student = selectedStudent {
                // Show courses for the selected student
                let studentCourses = courses.filter { $0.student.id == student.id }
                
                if !studentCourses.isEmpty {
                    Picker("Course", selection: $selectedCourse) {
                        Text("None").tag(nil as Course?)
                        ForEach(studentCourses) { course in
                            Text(course.name).tag(course as Course?)
                        }
                    }
                    .pickerStyle(.menu)
                } else {
                    Text("No courses available for this student")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            } else {
                Text("Select a student first to choose a course")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
    }
    
    private var hasCourse: Bool {
        return selectedCourse != nil
    }
    
    @MainActor
    private func loadCourses() async {
        guard !isLoadingCourses else { return }
        isLoadingCourses = true
        do {
            courses = try await APIClient.shared.fetchCourses()
        } catch {
            print("Failed to load courses for subject selection: \(error)")
        }
        isLoadingCourses = false
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

    @MainActor
    private func saveTask() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        // If course is provided, save as assignment
        if let course = selectedCourse {
            // Use selectedStudent if available, otherwise use the course's student
            let student = selectedStudent ?? course.student
            
            isSaving = true
            errorMessage = nil
            
            do {
                _ = try await APIClient.shared.createAssignment(
                    title: trimmedTitle,
                    studentId: student.id,
                    dueDate: date,
                    instructions: nil,
                    pointsPossible: nil,
                    pointsAwarded: nil,
                    courseId: course.id
                )
                onSaveAssignment()
                dismiss()
            } catch {
                errorMessage = "Failed to create assignment: \(error.localizedDescription)"
                isSaving = false
            }
        } else {
            // No course - save as planner task
            isSaving = true
            errorMessage = nil
            
            do {
                let task = try await APIClient.shared.createPlannerTask(
                    title: trimmedTitle,
                    startDate: date,
                    durationMinutes: durationMinutes,
                    colorName: selectedColorName,
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
}

#Preview {
    AddTaskView(initialDate: Date(), assignments: [], students: [], existingTaskIds: [], onSaveTask: { _ in }, onSaveAssignment: {})
}
