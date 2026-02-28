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
    let onTaskUpdated: (PlannerTask) -> Void
    let onAssignmentUpdated: (Assignment) -> Void
    let onTaskDeleted: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing: Bool = false
    @State private var editedTitle: String = ""
    @State private var editedDate: Date = Date()
    @State private var editedWorkDates: [Date] = []
    @State private var editedWorkDurationsMinutes: [Int] = []
    @State private var editedDueDate: Date = Date()
    @State private var hasDueDate: Bool = false
    @State private var editedDurationMinutes: Int = 60
    @State private var editedCourse: Course? = nil
    @State private var editedStudent: User? = nil
    @State private var editedStudentIds: Set<String> = []
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var linkedResources: [Resource] = []
    @State private var previewFileURL: URL?
    @State private var previewResourceType: ResourceType?

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

    private var isAssignmentTask: Bool {
        task.id.hasPrefix("assignment-")
    }

    private var isDueAssignmentTask: Bool {
        task.id.hasPrefix("assignment-due-")
    }
    
    
    init(task: PlannerTask, assignment: Assignment?, students: [User] = [], courses: [Course] = [], onTaskUpdated: @escaping (PlannerTask) -> Void = { _ in }, onAssignmentUpdated: @escaping (Assignment) -> Void = { _ in }, onTaskDeleted: @escaping () -> Void = {}) {
        self.task = task
        self.assignment = assignment
        self.students = students
        self.courses = courses
        self.onTaskUpdated = onTaskUpdated
        self.onAssignmentUpdated = onAssignmentUpdated
        self.onTaskDeleted = onTaskDeleted
        
        // Initialize edit state from task or assignment
        _editedTitle = State(initialValue: assignment?.title ?? task.title)
        // For assignments, use the assignment's dueDate; for tasks, use task.startDate
        let initialDate = assignment?.dueDate ?? task.startDate
        _editedDate = State(initialValue: initialDate)
        _editedWorkDates = State(initialValue: assignment?.workDates ?? [])
        _editedWorkDurationsMinutes = State(initialValue: assignment?.workDurationsMinutes ?? [])
        _editedDueDate = State(initialValue: assignment?.dueDate ?? task.startDate)
        _hasDueDate = State(initialValue: assignment?.dueDate != nil)
        _editedDurationMinutes = State(initialValue: task.durationMinutes)
        _editedStudentIds = State(initialValue: Set(task.studentIds))
        
        // Initialize course - try to find from assignment's courseId, task.subject, or courses array
        var initialCourse: Course? = nil
        if task.subject != nil {
            // Will be set in onAppear or startEditing when courses are loaded
            initialCourse = nil // Courses may not be loaded yet in init
        } else if let assignment = assignment, assignment.courseId != nil {
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
                        .disabled(isSaving || editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (editedCourse != nil && primaryEditedStudent == nil))
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
                        course.students.contains(where: { $0.id == student.id }) && course.assignments.contains { $0.id == assignment.id }
                    }
                }
            }
            .task(id: assignment?.id) {
                guard let assignment = assignment else { return }
                do {
                    linkedResources = try await api.fetchResourcesForAssignment(assignmentId: assignment.id)
                } catch {
                    linkedResources = []
                }
            }
            .sheet(isPresented: Binding(
                get: { previewFileURL != nil },
                set: { if !$0 { if let url = previewFileURL { try? FileManager.default.removeItem(at: url) }; previewFileURL = nil; previewResourceType = nil } }
            )) {
                if let url = previewFileURL {
                    ResourcePreviewView(url: url, resourceType: previewResourceType) {
                        if let u = previewFileURL { try? FileManager.default.removeItem(at: u) }
                        previewFileURL = nil
                        previewResourceType = nil
                    }
                }
            }
        }
    }

    private func openLinkedResource(_ resource: Resource) {
        if resource.type == .link, let u = resource.url, let url = URL(string: u) {
            UIApplication.shared.open(url)
            return
        }
        guard resource.fileUrl != nil else { return }
        Task {
            do {
                let localURL = try await api.downloadResourceFile(resourceId: resource.id, displayName: resource.displayName, mimeType: resource.mimeType)
                await MainActor.run { previewFileURL = localURL; previewResourceType = resource.type }
            } catch {
                await MainActor.run { errorMessage = "Could not open file: \(error.localizedDescription)" }
            }
        }
    }
    
    private var readOnlyView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header with task/assignment symbol indicator
            HStack(alignment: .top, spacing: 16) {
                if isAssignmentTask {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 18))
                            .foregroundColor(task.color)
                        if isDueAssignmentTask {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                                .offset(x: 4, y: -4)
                        }
                    }
                    .padding(.top, 4)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(task.color)
                        .padding(.top, 4)
                }
                
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
                        if !assignment.workDates.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Work Time")
                                    .font(.headline)
                                    .foregroundColor(.hatchEdText)

                                ForEach(Array(assignment.workDates.enumerated()), id: \.offset) { index, workDate in
                                    HStack {
                                        Image(systemName: "hammer.fill")
                                            .foregroundColor(.hatchEdAccent)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(dateFormatter.string(from: workDate))
                                                .font(.body)
                                                .foregroundColor(.hatchEdText)
                                            Text("Duration: \(durationLabel(assignment.workDurationsMinutes, index: index))")
                                                .font(.caption)
                                                .foregroundColor(.hatchEdSecondaryText)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.hatchEdCardBackground)
                            )
                        }

                        // Due Date
                        if let dueDate = assignment.dueDate {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Due Date")
                                    .font(.headline)
                                    .foregroundColor(.hatchEdText)
                                
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text(dateFormatter.string(from: dueDate))
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.hatchEdText)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red.opacity(0.45), lineWidth: 1)
                                    )
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

                    // Linked resources (for assignments – parent can attach resources to help student)
                    if assignment != nil, !linkedResources.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Resources")
                                .font(.headline)
                                .foregroundColor(.hatchEdText)
                            ForEach(linkedResources) { resource in
                                Button {
                                    openLinkedResource(resource)
                                } label: {
                                    HStack {
                                        Image(systemName: resource.type.systemImage)
                                            .foregroundColor(.hatchEdAccent)
                                        Text(resource.displayName)
                                            .foregroundColor(.hatchEdText)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Image(systemName: "arrow.up.forward")
                                            .font(.caption)
                                            .foregroundColor(.hatchEdSecondaryText)
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
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
                if assignment != nil {
                    if editedWorkDates.isEmpty {
                        Button("Add Work Date & Time") {
                            editedWorkDates.append(editedDate)
                            editedWorkDurationsMinutes.append(60)
                        }
                    } else {
                        ForEach(editedWorkDates.indices, id: \.self) { index in
                            DatePicker("Work Time \(index + 1)", selection: Binding(
                                get: { editedWorkDates[index] },
                                set: { editedWorkDates[index] = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                            Stepper(value: Binding(
                                get: {
                                    index < editedWorkDurationsMinutes.count ? editedWorkDurationsMinutes[index] : 60
                                },
                                set: { newValue in
                                    if index >= editedWorkDurationsMinutes.count {
                                        editedWorkDurationsMinutes.append(contentsOf: Array(repeating: 60, count: index - editedWorkDurationsMinutes.count + 1))
                                    }
                                    editedWorkDurationsMinutes[index] = newValue
                                }
                            ), in: 15...480, step: 15) {
                                Text("Duration: \(formattedDurationValue(index < editedWorkDurationsMinutes.count ? editedWorkDurationsMinutes[index] : 60))")
                            }
                        }
                        .onDelete { offsets in
                            editedWorkDates.remove(atOffsets: offsets)
                            editedWorkDurationsMinutes.remove(atOffsets: offsets)
                        }
                        Button("Add Another Work Time") {
                            editedWorkDates.append(editedWorkDates.last ?? editedDate)
                            editedWorkDurationsMinutes.append(editedWorkDurationsMinutes.last ?? 60)
                        }
                    }
                    Toggle("Has Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due Date & Time", selection: $editedDueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                } else {
                    DatePicker("Date & Time", selection: $editedDate, displayedComponents: [.date, .hourAndMinute])
                    Stepper(value: $editedDurationMinutes, in: 15...480, step: 15) {
                        Text("Duration: \(formattedDuration)")
                    }
                }
            }
            
            // Show Student section for assignments and planner tasks when students exist.
            if assignment != nil || !students.isEmpty {
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
                            // For planner tasks, allow multi-student selection
                            ForEach(students) { student in
                                Toggle(isOn: Binding(
                                    get: { editedStudentIds.contains(student.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            editedStudentIds.insert(student.id)
                                        } else {
                                            editedStudentIds.remove(student.id)
                                        }
                                        editedStudent = primaryEditedStudent
                                    }
                                )) {
                                    Text(student.name ?? "Student")
                                }
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
            if primaryEditedStudent != nil || assignment != nil || editedCourse != nil || task.subject != nil || displayCourse != nil {
                Section(header: Text("Course")) {
                    courseSelection
                }
            }
            
        }
    }
    
    private var courseSelection: some View {
        VStack(spacing: 12) {
            if let student = primaryEditedStudent ?? displayStudent {
                // Show courses for the selected student
                let studentCourses = courses.filter { $0.students.contains(where: { $0.id == student.id }) }
                
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
                    course.students.contains(where: { $0.id == student.id }) && course.assignments.contains { $0.id == assignment.id }
                }
            }
        }
        
        return nil
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

    private func formattedDurationValue(_ durationMinutes: Int) -> String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 {
            return minutes == 0 ? "\(hours) hr" : "\(hours) hr \(minutes) min"
        }
        return "\(minutes) min"
    }

    private func durationLabel(_ durations: [Int], index: Int) -> String {
        let duration = index < durations.count ? max(15, durations[index]) : 60
        return formattedDurationValue(duration)
    }

    private var normalizedEditedWorkDurations: [Int] {
        editedWorkDates.indices.map { index in
            let duration = index < editedWorkDurationsMinutes.count ? editedWorkDurationsMinutes[index] : 60
            return max(15, duration)
        }
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
        return primaryEditedStudent ?? editedStudent
    }

    private var primaryEditedStudent: User? {
        if let editedStudent {
            return editedStudent
        }
        if let firstSelectedId = editedStudentIds.first {
            return students.first(where: { $0.id == firstSelectedId })
        }
        return nil
    }
    
    private func calculatePercentage(pointsAwarded: Double, pointsPossible: Double) -> Double? {
        guard pointsPossible > 0 else { return nil }
        return (pointsAwarded / pointsPossible) * 100
    }
    
    private func startEditing() {
        isEditing = true
        // Reset edit state to current task or assignment values
        editedTitle = assignment?.title ?? task.title
        // For assignments, use the assignment's dueDate; for tasks, use task.startDate
        editedDate = assignment?.dueDate ?? task.startDate
        editedWorkDates = assignment?.workDates ?? []
        editedWorkDurationsMinutes = assignment?.workDurationsMinutes ?? []
        editedDueDate = assignment?.dueDate ?? task.startDate
        hasDueDate = assignment?.dueDate != nil
        editedDurationMinutes = task.durationMinutes
        editedStudentIds = Set(task.studentIds)
        
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
                    course.students.contains(where: { $0.id == student.id }) && course.assignments.contains { $0.id == assignment.id }
                })
            }
        }
        
        editedCourse = courseToSet
        
        // If this is an assignment, set student
        if let assignment = assignment {
            editedStudent = students.first { $0.id == assignment.studentId }
        } else {
            editedStudent = primaryEditedStudent
        }
        errorMessage = nil
    }
    
    private func cancelEditing() {
        isEditing = false
        // Reset to original values
        editedTitle = assignment?.title ?? task.title
        editedDate = assignment?.dueDate ?? task.startDate
        editedWorkDates = assignment?.workDates ?? []
        editedWorkDurationsMinutes = assignment?.workDurationsMinutes ?? []
        editedDueDate = assignment?.dueDate ?? task.startDate
        hasDueDate = assignment?.dueDate != nil
        editedDurationMinutes = task.durationMinutes
        editedStudentIds = Set(task.studentIds)
        
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
            editedStudent = primaryEditedStudent
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
                let updatedAssignment = try await api.updateAssignment(
                    id: assignment.id,
                    title: trimmedTitle,
                    workDates: editedWorkDates.isEmpty ? nil : editedWorkDates,
                    workDurationsMinutes: editedWorkDates.isEmpty ? nil : normalizedEditedWorkDurations,
                    dueDate: hasDueDate ? editedDueDate : nil,
                    clearDueDate: hasDueDate ? nil : true,
                    instructions: nil,
                    pointsPossible: nil,
                    pointsAwarded: nil,
                    courseId: editedCourse?.id
                )
                onAssignmentUpdated(updatedAssignment)
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
                guard let student = primaryEditedStudent ?? newCourse?.student else {
                    errorMessage = "Please select a student when adding a course"
                    isSaving = false
                    return
                }
                
                // Create assignment and delete planner task
                do {
                    // Use the selected course
                    let createdAssignment = try await api.createAssignment(
                        title: trimmedTitle,
                        studentId: student.id,
                        workDates: [editedDate],
                        workDurationsMinutes: [editedDurationMinutes],
                        dueDate: nil,
                        instructions: nil,
                        pointsPossible: nil,
                        pointsAwarded: nil,
                        courseId: newCourse?.id
                    )
                    
                    // Delete the original planner task
                    try await api.deletePlannerTask(id: task.id)
                    
                    onTaskDeleted()
                    onAssignmentUpdated(createdAssignment)
                    dismiss()
                } catch {
                    errorMessage = "Failed to convert task to assignment: \(error.localizedDescription)"
                    isSaving = false
                }
            } else {
                // Regular update of planner task
                do {
                    let updatedTask = try await api.updatePlannerTask(
                        id: task.id,
                        title: trimmedTitle,
                        startDate: editedDate,
                        durationMinutes: editedDurationMinutes,
                        colorName: "Blue",
                        subject: newSubject,
                        studentIds: Array(editedStudentIds)
                    )
                    onTaskUpdated(updatedTask)
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

