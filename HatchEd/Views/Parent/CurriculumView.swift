//
//  CurriculumView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI

struct CurriculumView: View {
    @EnvironmentObject private var signInManager: AppleSignInManager
    @State private var courses: [Course] = []
    @State private var assignments: [Assignment] = []
    @State private var showingAddSheet = false
    @State private var addSheetType: AddType? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let api = APIClient.shared
    
    enum AddType: Identifiable {
        case course
        case assignment
        
        var id: String {
            switch self {
            case .course: return "course"
            case .assignment: return "assignment"
            }
        }
        
        var title: String {
            switch self {
            case .course: return "Add Course"
            case .assignment: return "Add Assignment"
            }
        }
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if courses.isEmpty && assignments.isEmpty {
                        emptyStateView
                    } else {
                        coursesSection
                        assignmentsSection
                    }
                }
                .padding()
                .padding(.bottom, 80) // Space for floating button
            }
            
            // Floating Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingAddSheet = true
                    }) {
            Image(systemName: "plus")
                .font(.title2)
                .foregroundColor(.hatchEdWhite)
                .frame(width: 56, height: 56)
                .background(Color.hatchEdAccent)
                .clipShape(Circle())
                .shadow(color: .hatchEdDarkGray.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Curriculum")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await loadCurriculum()
            }
        }
        .refreshable {
            await loadCurriculum()
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
        .confirmationDialog("Add New Item", isPresented: $showingAddSheet, titleVisibility: .visible) {
            Button("Course") {
                addSheetType = .course
            }
            Button("Assignment") {
                addSheetType = .assignment
            }
            Button("Cancel", role: .cancel) {
                addSheetType = nil
            }
        }
        .sheet(item: $addSheetType) { type in
            NavigationView {
                AddItemView(
                    type: type,
                    courses: $courses,
                    assignments: $assignments,
                    students: signInManager.students,
                    errorMessage: $errorMessage
                )
            }
        }
    }
    
    @MainActor
    private func loadCurriculum() async {
        isLoading = true
        errorMessage = nil
        do {
            async let coursesTask = api.fetchCourses()
            async let assignmentsTask = api.fetchAssignments()
            
            courses = try await coursesTask
            assignments = try await assignmentsTask
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 64))
                .foregroundColor(.hatchEdSecondaryText)
            Text("No curriculum items yet")
                .font(.headline)
                .foregroundColor(.hatchEdSecondaryText)
            Text("Tap the + button to add courses or assignments")
                .font(.subheadline)
                .foregroundColor(.hatchEdSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.hatchEdSuccess)
                Text("Courses")
                    .font(.headline)
                    .foregroundColor(.hatchEdText)
            }
            
            if courses.isEmpty {
                Text("No courses yet")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.hatchEdSecondaryBackground))
            } else {
                ForEach(courses) { course in
                    CourseRow(course: course)
                }
            }
        }
    }
    
    private var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.hatchEdWarning)
                Text("Assignments")
                    .font(.headline)
                    .foregroundColor(.hatchEdText)
            }
            
            if assignments.isEmpty {
                Text("No assignments yet")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.hatchEdSecondaryBackground))
            } else {
                ForEach(assignments) { assignment in
                    AssignmentRow(assignment: assignment)
                }
            }
        }
    }
}

private struct CourseRow: View {
    let course: Course
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.hatchEdWhite)
                    .font(.title3)
                    .padding(8)
                    .background(Color.hatchEdSuccess)
                    .clipShape(Circle())
                Text(course.name)
                    .foregroundColor(.hatchEdText)
                    .fontWeight(.medium)
                Spacer()
                if let grade = course.grade {
                    Text(String(format: "%.1f%%", grade))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.hatchEdSuccess)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.hatchEdSuccess.opacity(0.15))
                        .cornerRadius(8)
                }
            }
            Text(course.student.name ?? "Student")
                .font(.caption)
                .foregroundColor(.hatchEdSecondaryText)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdCardBackground)
                .shadow(color: Color.hatchEdSuccess.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }
}

private struct AssignmentRow: View {
    let assignment: Assignment
    
    private func calculatePercentage(pointsAwarded: Double, pointsPossible: Double) -> Double? {
        guard pointsPossible > 0 else { return nil }
        return (pointsAwarded / pointsPossible) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.hatchEdWhite)
                    .font(.title3)
                    .padding(8)
                    .background(Color.hatchEdWarning)
                    .clipShape(Circle())
                Text(assignment.title)
                    .foregroundColor(.hatchEdText)
                    .fontWeight(.medium)
                Spacer()
                if let pointsAwarded = assignment.pointsAwarded,
                   let pointsPossible = assignment.pointsPossible,
                   pointsPossible > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f/%.0f", pointsAwarded, pointsPossible))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.hatchEdWarning)
                        if let percentage = calculatePercentage(pointsAwarded: pointsAwarded, pointsPossible: pointsPossible) {
                            Text(String(format: "%.0f%%", percentage))
                                .font(.caption2)
                                .foregroundColor(.hatchEdSecondaryText)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.hatchEdWarning.opacity(0.15))
                    .cornerRadius(8)
                }
            }
            if let dueDate = assignment.dueDate {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundColor(.hatchEdWarning)
                    Text("Due: \(dueDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.hatchEdSecondaryText)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdCardBackground)
                .shadow(color: Color.hatchEdWarning.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }
}

private struct AddItemView: View {
    let type: CurriculumView.AddType
    @Binding var courses: [Course]
    @Binding var assignments: [Assignment]
    let students: [User]
    @Binding var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    @State private var courseName = ""
    @State private var selectedStudentForCourse: User?
    @State private var assignmentTitle = ""
    @State private var assignmentDueDate = Date()
    @State private var selectedCourseForAssignment: Course?
    @State private var selectedStudentForAssignment: User?
    @State private var hasDueDate = false
    
    var body: some View {
        Form {
            switch type {
            case .course:
                Section(header: Text("Course Details")) {
                    TextField("Enter course name", text: $courseName)
                    
                    if !students.isEmpty {
                        Picker("Student", selection: Binding(
                            get: { selectedStudentForCourse?.id },
                            set: { id in
                                selectedStudentForCourse = students.first { $0.id == id }
                            }
                        )) {
                            Text("Select a student").tag(nil as String?)
                            ForEach(students) { student in
                                Text(student.name ?? "Student").tag(student.id as String?)
                            }
                        }
                    }
                }
                
            case .assignment:
                Section(header: Text("Assignment Details")) {
                    TextField("Enter assignment title", text: $assignmentTitle)
                    
                    if !students.isEmpty {
                        Picker("Student", selection: Binding(
                            get: { selectedStudentForAssignment?.id },
                            set: { id in
                                selectedStudentForAssignment = students.first { $0.id == id }
                            }
                        )) {
                            Text("Select a student").tag(nil as String?)
                            ForEach(students) { student in
                                Text(student.name ?? "Student").tag(student.id as String?)
                            }
                        }
                    }
                    
                    Toggle("Has Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due Date", selection: $assignmentDueDate, displayedComponents: .date)
                    }
                    
                    if !courses.isEmpty {
                        Picker("Course", selection: Binding(
                            get: { selectedCourseForAssignment?.id },
                            set: { id in
                                selectedCourseForAssignment = courses.first { $0.id == id }
                            }
                        )) {
                            Text("None").tag(nil as String?)
                            ForEach(courses) { course in
                                Text(course.name).tag(course.id as String?)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await saveItem()
                    }
                }
                .disabled(!isValid)
            }
        }
    }
    
    private var isValid: Bool {
        switch type {
        case .course:
            return !courseName.trimmingCharacters(in: .whitespaces).isEmpty && selectedStudentForCourse != nil
        case .assignment:
            return !assignmentTitle.trimmingCharacters(in: .whitespaces).isEmpty && selectedStudentForAssignment != nil
        }
    }
    
    @MainActor
    private func saveItem() async {
        let api = APIClient.shared
        do {
            switch type {
            case .course:
                guard let student = selectedStudentForCourse else { return }
                let newCourse = try await api.createCourse(
                    name: courseName.trimmingCharacters(in: .whitespaces),
                    studentUserId: student.id,
                    grade: nil
                )
                courses.append(newCourse)
                
            case .assignment:
                guard let student = selectedStudentForAssignment else { return }
                let newAssignment = try await api.createAssignment(
                    title: assignmentTitle.trimmingCharacters(in: .whitespaces),
                    studentId: student.id,
                    dueDate: hasDueDate ? assignmentDueDate : nil,
                    instructions: nil,
                    pointsPossible: nil,
                    pointsAwarded: nil,
                    courseId: selectedCourseForAssignment?.id
                )
                assignments.append(newAssignment)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationView {
        CurriculumView()
    }
}

