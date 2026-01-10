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
    let students: [User]
    let courses: [Course]
    let onTaskUpdated: () -> Void
    let onAssignmentUpdated: () -> Void
    let onTaskDeleted: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing: Bool = false
    @State private var editedTitle: String = ""
    @State private var editedDate: Date = Date()
    @State private var editedDurationMinutes: Int = 60
    @State private var editedColorName: String = "Blue"
    @State private var editedCourse: Course? = nil
    @State private var editedStudent: User? = nil
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    
    private let api = APIClient.shared
    
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
    
    
    init(task: PlannerTask, assignment: Assignment?, students: [User] = [], courses: [Course] = [], onTaskUpdated: @escaping () -> Void = {}, onAssignmentUpdated: @escaping () -> Void = {}, onTaskDeleted: @escaping () -> Void = {}) {
        self.task = task
        self.assignment = assignment
        self.students = students
        self.courses = courses
        self.onTaskUpdated = onTaskUpdated
        self.onAssignmentUpdated = onAssignmentUpdated
        self.onTaskDeleted = onTaskDeleted
        
        // Initialize edit state from task or assignment
        _editedTitle = State(initialValue: task.title)
        // For assignments, use the assignment's dueDate; for tasks, use task.startDate
        let initialDate = assignment?.dueDate ?? task.startDate
        _editedDate = State(initialValue: initialDate)
        _editedDurationMinutes = State(initialValue: task.durationMinutes)
        _editedColorName = State(initialValue: task.colorName)
        
        // Initialize course - try to find from assignment's courseId, task.subject, or courses array
        var initialCourse: Course? = nil
        if let subject = task.subject {
            // Will be set in onAppear or startEditing when courses are loaded
            initialCourse = nil // Courses may not be loaded yet in init
        } else if let assignment = assignment, let courseId = assignment.courseId {
            // Will try to find course by courseId when courses are loaded
            initialCourse = nil // Courses may not be loaded yet in init
        }
        _editedCourse = State(initialValue: initialCourse)
        
        // If this is an assignment, get the student from the assignment
        if let assignment = assignment {
            _editedStudent = State(initialValue: students.first { $0.id == assignment.studentId })
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isEditing {
                    Form {
                        editingView
                    }
                } else {
                    ScrollView {
                        readOnlyView
                    }
                }
            }
            .navigationTitle(isEditing ? (assignment != nil ? "Edit Assignment" : "Edit Task") : (assignment != nil ? "Assignment Details" : "Task Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            cancelEditing()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await saveChanges()
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.hatchEdAccent)
                        .disabled(isSaving || editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (editedCourse != nil && editedStudent == nil))
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") {
                            startEditing()
                        }
                    }
                }
            }
            .background(Color.hatchEdBackground)
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .onAppear {
                // Initialize or refresh editedCourse when view appears based on assignment's courseId
                // This ensures the course is displayed correctly even after updates
                var courseToSet: Course? = nil
                
                if let subject = task.subject {
                    courseToSet = courses.first { $0.name == subject }
                } else if let assignment = assignment, let courseId = assignment.courseId {
                    // Prioritize courseId from assignment - this will be updated after save
                    courseToSet = courses.first { $0.id == courseId }
                }
                
                // Only update if we found a course, or if editedCourse is nil
                if let course = courseToSet {
                    editedCourse = course
                } else if editedCourse == nil, let assignment = assignment,
                          let student = students.first(where: { $0.id == assignment.studentId }) {
                    // Fallback: find course from assignments list
                    editedCourse = courses.first { course in
                        course.student.id == student.id && course.assignments.contains { $0.id == assignment.id }
                    }
                }
            }
        }
    }
    
    private var readOnlyView: some View {
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
                    
                    // Student Information (show for assignments or if task has subject)
                    if let student = displayStudent {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Student")
                                .font(.headline)
                                .foregroundColor(.hatchEdText)
                            
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.hatchEdAccent)
                                Text(student.name ?? "Student")
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
                    
                    // Course Information (show if course exists)
                    if let course = displayCourse {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Course")
                                .font(.headline)
                                .foregroundColor(.hatchEdText)
                            
                            HStack {
                                Image(systemName: "book.fill")
                                    .foregroundColor(.hatchEdAccent)
                                Text(course.name)
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
    
    private var editingView: some View {
        List {
            Section(header: Text("Task")) {
                TextField("Title", text: $editedTitle)
                DatePicker("Date & Time", selection: $editedDate, displayedComponents: [.date, .hourAndMinute])
                Stepper(value: $editedDurationMinutes, in: 15...480, step: 15) {
                    Text("Duration: \(formattedDuration)")
                }
            }
            
            // Show Student section if it's an assignment (always has student) OR if subject exists
            if assignment != nil || task.subject != nil || displayCourse != nil {
                Section(header: Text("Student")) {
                    if !students.isEmpty {
                        if assignment != nil {
                            // For assignments, show the student as read-only since they're tied to a specific student
                            if let currentStudent = displayStudent {
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.hatchEdAccent)
                                    Text(currentStudent.name ?? "Student")
                                        .foregroundColor(.hatchEdText)
                                    Spacer()
                                    Text("(Cannot change)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // For planner tasks, allow selection
                            Picker("Select Student", selection: $editedStudent) {
                                Text("Select a student").tag(nil as User?)
                                ForEach(students) { student in
                                    Text(student.name ?? "Student").tag(student as User?)
                                }
                            }
                            .onChange(of: editedStudent) { newStudent in
                                // Clear course selection when student changes
                                editedCourse = nil
                            }
                        }
                    } else {
                        Text("No students available")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            
            // Show Course section if student is selected or if it's an assignment
            if editedStudent != nil || assignment != nil || editedCourse != nil || task.subject != nil || displayCourse != nil {
                Section(header: Text("Course")) {
                    courseSelection
                }
            }
            
            Section(header: Text("Color")) {
                colorSelection
            }
        }
    }
    
    private var courseSelection: some View {
        VStack(spacing: 12) {
            if let student = editedStudent ?? displayStudent {
                // Show courses for the selected student
                let studentCourses = courses.filter { $0.student.id == student.id }
                
                if !studentCourses.isEmpty {
                    Picker("Course", selection: $editedCourse) {
                        Text("None").tag(nil as Course?)
                        ForEach(studentCourses) { course in
                            Text(course.name).tag(course as Course?)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // Show current course if it exists but isn't selected
                    if let currentCourse = displayCourse, editedCourse == nil {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text("Current course: \(currentCourse.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
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
    
    // Get the course that should be displayed based on current task/assignment
    private var displayCourse: Course? {
        // If we have a selected course in edit mode, use it
        if let course = editedCourse {
            return course
        }
        
        // Try to find course from task.subject (course name)
        if let subject = task.subject {
            return courses.first { $0.name == subject }
        }
        
        // For assignments, first try to find course by assignment's courseId if available
        if let assignment = assignment {
            if let courseId = assignment.courseId {
                if let course = courses.first(where: { $0.id == courseId }) {
                    return course
                }
            }
            // Fallback: try to find the course that contains this assignment in its assignments list
            if let student = students.first(where: { $0.id == assignment.studentId }) {
                return courses.first { course in
                    course.student.id == student.id && course.assignments.contains { $0.id == assignment.id }
                }
            }
        }
        
        return nil
    }
    
    private var colorSelection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(PlannerTask.colorOptions, id: \.name) { option in
                Button {
                    editedColorName = option.name
                } label: {
                    Circle()
                        .fill(option.color)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(editedColorName == option.name ? 0.9 : 0), lineWidth: 3)
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
    
    private var hasCourse: Bool {
        return editedCourse != nil
    }
    
    private var finalCourse: Course? {
        return editedCourse
    }
    
    private var formattedDuration: String {
        let hours = editedDurationMinutes / 60
        let minutes = editedDurationMinutes % 60
        if hours > 0 {
            return minutes == 0 ? "\(hours) hr" : "\(hours) hr \(minutes) min"
        }
        return "\(minutes) min"
    }
    
    private var durationString: String {
        let hours = task.durationMinutes / 60
        let minutes = task.durationMinutes % 60
        if hours > 0 {
            return minutes == 0 ? "\(hours) hr" : "\(hours) hr \(minutes) min"
        }
        return "\(minutes) min"
    }
    
    // Get the display student - either from assignment or if course exists
    private var displayStudent: User? {
        if let assignment = assignment {
            return students.first { $0.id == assignment.studentId }
        }
        // For planner tasks with course, use the course's student or editedStudent
        if let course = displayCourse {
            return course.student
        }
        return editedStudent
    }
    
    private func calculatePercentage(pointsAwarded: Double, pointsPossible: Double) -> Double? {
        guard pointsPossible > 0 else { return nil }
        return (pointsAwarded / pointsPossible) * 100
    }
    
    private func startEditing() {
        isEditing = true
        // Reset edit state to current task or assignment values
        editedTitle = task.title
        // For assignments, use the assignment's dueDate; for tasks, use task.startDate
        editedDate = assignment?.dueDate ?? task.startDate
        editedDurationMinutes = task.durationMinutes
        editedColorName = task.colorName
        
        // Initialize course - prefer course from task.subject, otherwise try to find from assignment
        var courseToSet: Course? = nil
        
        // If task has a subject (course name), find the matching course
        if let subject = task.subject {
            courseToSet = courses.first { $0.name == subject }
        }
        
        // If not found and this is an assignment, try to find the course from the assignment
        if courseToSet == nil, let assignment = assignment {
            // First, try to find course by assignment's courseId if available
            if let courseId = assignment.courseId {
                courseToSet = courses.first { $0.id == courseId }
            }
            // Fallback: try to find course from assignments list
            if courseToSet == nil, let student = students.first(where: { $0.id == assignment.studentId }) {
                courseToSet = courses.first(where: { course in
                    course.student.id == student.id && course.assignments.contains { $0.id == assignment.id }
                })
            }
        }
        
        editedCourse = courseToSet
        
        // If this is an assignment, set student
        if let assignment = assignment {
            editedStudent = students.first { $0.id == assignment.studentId }
        }
        errorMessage = nil
    }
    
    private func cancelEditing() {
        isEditing = false
        // Reset to original values
        editedTitle = task.title
        editedDate = assignment?.dueDate ?? task.startDate
        editedDurationMinutes = task.durationMinutes
        editedColorName = task.colorName
        
        // Reset course - find course from task.subject if it exists
        if let subject = task.subject {
            editedCourse = courses.first { $0.name == subject }
        } else {
            editedCourse = nil
        }
        
        // Reset student if needed
        if let assignment = assignment {
            editedStudent = students.first { $0.id == assignment.studentId }
        } else {
            editedStudent = nil
        }
        errorMessage = nil
    }
    
    @MainActor
    private func saveChanges() async {
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Title is required"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        // Check if this is an assignment or planner task
        if let assignment = assignment {
            // Update assignment
            do {
                _ = try await api.updateAssignment(
                    id: assignment.id,
                    title: trimmedTitle,
                    dueDate: editedDate,
                    instructions: nil,
                    pointsPossible: nil,
                    pointsAwarded: nil,
                    courseId: editedCourse?.id
                )
                onAssignmentUpdated()
                dismiss()
            } catch {
                errorMessage = "Failed to update assignment: \(error.localizedDescription)"
                isSaving = false
            }
        } else {
            // This is a planner task
            let newCourse = editedCourse
            let newSubject = newCourse?.name // Use course name as subject for the planner task
            
            // Check if we're adding a course to a previously course-less task
            let hadCourseBefore = task.subject != nil
            let hasCourseNow = newCourse != nil
            
            if !hadCourseBefore && hasCourseNow {
                // Converting planner task to assignment - need student
                guard let student = editedStudent ?? newCourse?.student else {
                    errorMessage = "Please select a student when adding a course"
                    isSaving = false
                    return
                }
                
                // Create assignment and delete planner task
                do {
                    // Use the selected course
                    _ = try await api.createAssignment(
                        title: trimmedTitle,
                        studentId: student.id,
                        dueDate: editedDate,
                        instructions: nil,
                        pointsPossible: nil,
                        pointsAwarded: nil,
                        courseId: newCourse?.id
                    )
                    
                    // Delete the original planner task
                    try await api.deletePlannerTask(id: task.id)
                    
                    onTaskDeleted()
                    onAssignmentUpdated()
                    dismiss()
                } catch {
                    errorMessage = "Failed to convert task to assignment: \(error.localizedDescription)"
                    isSaving = false
                }
            } else {
                // Regular update of planner task
                do {
                    _ = try await api.updatePlannerTask(
                        id: task.id,
                        title: trimmedTitle,
                        startDate: editedDate,
                        durationMinutes: editedDurationMinutes,
                        colorName: editedColorName,
                        subject: newSubject
                    )
                    onTaskUpdated()
                    dismiss()
                } catch {
                    errorMessage = "Failed to update task: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    TaskDetailSheetView(
        task: PlannerTask(
            id: "1",
            title: "Math Homework",
            startDate: Date(),
            durationMinutes: 90,
            colorName: "Blue",
            subject: "Math"
        ),
        assignment: nil,
        students: [],
        courses: []
    )
}

