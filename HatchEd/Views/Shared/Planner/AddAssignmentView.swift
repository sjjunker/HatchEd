//
//  AddAssignmentView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//

import SwiftUI

struct AddAssignmentView: View {
    @Environment(\.dismiss) private var dismiss

    let initialDate: Date
    let students: [User]
    let onSaveAssignment: () -> Void

    @State private var title: String = ""
    @State private var dueDate: Date
    @State private var hasDueDate: Bool = true
    @State private var selectedStudent: User? = nil
    @State private var selectedCourse: Course? = nil
    @State private var courses: [Course] = []
    @State private var isLoadingCourses: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    private let api = APIClient.shared

    init(initialDate: Date, students: [User] = [], onSaveAssignment: @escaping () -> Void) {
        self.initialDate = initialDate
        self.students = students
        self.onSaveAssignment = onSaveAssignment
        _dueDate = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Assignment Details")) {
                    TextField("Title", text: $title)
                    
                    Toggle("Has Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due Date & Time", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section(header: Text("Student")) {
                    if !students.isEmpty {
                        Picker("Select Student", selection: $selectedStudent) {
                            Text("Select a student").tag(nil as User?)
                            ForEach(students) { student in
                                Text(student.name ?? "Student").tag(student as User?)
                            }
                        }
                        .onChange(of: selectedStudent) { oldValue, newValue in
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
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveAssignment()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.hatchEdAccent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || selectedStudent == nil)
                }
            }
        }
        .presentationDetents([.fraction(0.75), .large])
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
    
    @MainActor
    private func loadCourses() async {
        guard !isLoadingCourses else { return }
        isLoadingCourses = true
        do {
            courses = try await api.fetchCourses()
        } catch {
            print("Failed to load courses: \(error)")
        }
        isLoadingCourses = false
    }

    @MainActor
    private func saveAssignment() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Title is required"
            return
        }
        
        guard let student = selectedStudent else {
            errorMessage = "Please select a student"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            _ = try await api.createAssignment(
                title: trimmedTitle,
                studentId: student.id,
                dueDate: hasDueDate ? dueDate : nil,
                instructions: nil,
                pointsPossible: nil,
                pointsAwarded: nil,
                courseId: selectedCourse?.id
            )
            onSaveAssignment()
            dismiss()
        } catch {
            errorMessage = "Failed to create assignment: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

#Preview {
    AddAssignmentView(initialDate: Date(), students: [], onSaveAssignment: {})
}

