//
//  AssignmentGradingView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct AssignmentGradingView: View {
    let assignment: Assignment
    let courses: [Course]
    let onGradeSaved: (Assignment) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var pointsPossible: String = ""
    @State private var pointsAwarded: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    private let api = APIClient.shared
    
    init(assignment: Assignment, courses: [Course], onGradeSaved: @escaping (Assignment) -> Void) {
        self.assignment = assignment
        self.courses = courses
        self.onGradeSaved = onGradeSaved
        if let pointsPossible = assignment.pointsPossible {
            _pointsPossible = State(initialValue: String(format: "%.1f", pointsPossible))
        } else {
            _pointsPossible = State(initialValue: "")
        }
        if let pointsAwarded = assignment.pointsAwarded {
            _pointsAwarded = State(initialValue: String(format: "%.1f", pointsAwarded))
        } else {
            _pointsAwarded = State(initialValue: "")
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Assignment Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(assignment.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.hatchEdText)
                        
                        if let dueDate = assignment.dueDate {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.hatchEdAccent)
                                Text("Due: \(dueDate, style: .date)")
                                    .font(.subheadline)
                                    .foregroundColor(.hatchEdText)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.hatchEdCardBackground)
                    )
                    
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
                    
                    // Grading Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Grade Assignment")
                            .font(.headline)
                            .foregroundColor(.hatchEdText)
                        
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Points Possible")
                                        .font(.subheadline)
                                        .foregroundColor(.hatchEdSecondaryText)
                                    
                                    TextField("Enter points", text: $pointsPossible)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 140)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Points Awarded")
                                        .font(.subheadline)
                                        .foregroundColor(.hatchEdSecondaryText)
                                    
                                    TextField("Enter points", text: $pointsAwarded)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 140)
                                }
                                
                                Spacer()
                            }
                            
                            // Show current grade if available
                            if let currentPercentage = currentGradePercentage {
                                HStack {
                                    Text("Current Grade:")
                                        .font(.subheadline)
                                        .foregroundColor(.hatchEdSecondaryText)
                                    Text(String(format: "%.1f%%", currentPercentage))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.hatchEdSuccess)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.hatchEdSuccess.opacity(0.1))
                                )
                            }
                            
                            // Show calculated percentage if both points are entered
                            if let calculatedPercentage = calculatedGradePercentage {
                                HStack {
                                    Text("Calculated Grade:")
                                        .font(.subheadline)
                                        .foregroundColor(.hatchEdSecondaryText)
                                    Text(String(format: "%.1f%%", calculatedPercentage))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.hatchEdAccent)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.hatchEdAccent.opacity(0.1))
                                )
                            }
                        }
                        
                        if let relatedCourse = relatedCourse {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Course: \(relatedCourse.name)")
                                    .font(.subheadline)
                                    .foregroundColor(.hatchEdSecondaryText)
                                
                                if let courseGrade = calculateCourseGrade(for: relatedCourse) {
                                    Text("Course Average: \(String(format: "%.1f%%", courseGrade))")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.hatchEdText)
                                } else {
                                    Text("No graded assignments yet")
                                        .font(.caption)
                                        .foregroundColor(.hatchEdSecondaryText)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.hatchEdAccentBackground)
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.hatchEdCardBackground)
                    )
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.hatchEdCoralAccent)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.hatchEdCoralAccent.opacity(0.1))
                            )
                    }
                }
                .padding()
            }
            .navigationTitle("Grade Assignment")
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
                            await saveGrade()
                        }
                    }
                    .disabled(isSaving || !isValidPoints)
                }
            }
            .background(Color.hatchEdBackground)
        }
    }
    
    private var relatedCourse: Course? {
        // Find the course that contains this assignment
        courses.first { course in
            course.assignments.contains { $0.id == assignment.id }
        }
    }
    
    
    private func calculateCourseGrade(for course: Course) -> Double? {
        calculateCourseGradeFromAssignments(course.assignments)
    }
    
    private var currentGradePercentage: Double? {
        guard let pointsAwarded = assignment.pointsAwarded,
              let pointsPossible = assignment.pointsPossible,
              pointsPossible > 0 else {
            return nil
        }
        return (pointsAwarded / pointsPossible) * 100
    }
    
    private var calculatedGradePercentage: Double? {
        guard let pointsAwarded = Double(pointsAwarded),
              let pointsPossible = Double(pointsPossible),
              pointsPossible > 0 else {
            return nil
        }
        return (pointsAwarded / pointsPossible) * 100
    }
    
    private func calculateCourseGradeFromAssignments(_ assignments: [Assignment]) -> Double? {
        let gradedAssignments = assignments.filter { assignment in
            assignment.pointsAwarded != nil && assignment.pointsPossible != nil && assignment.pointsPossible! > 0
        }
        guard !gradedAssignments.isEmpty else { return nil }
        
        let percentages = gradedAssignments.compactMap { assignment -> Double? in
            guard let pointsAwarded = assignment.pointsAwarded,
                  let pointsPossible = assignment.pointsPossible,
                  pointsPossible > 0 else {
                return nil
            }
            return (pointsAwarded / pointsPossible) * 100
        }
        
        guard !percentages.isEmpty else { return nil }
        let totalPercentage = percentages.reduce(0.0) { $0 + $1 }
        return totalPercentage / Double(percentages.count)
    }
    
    private var isValidPoints: Bool {
        guard let pointsPossibleValue = Double(pointsPossible),
              let pointsAwardedValue = Double(pointsAwarded) else {
            return false
        }
        return pointsPossibleValue > 0 && pointsAwardedValue >= 0 && pointsAwardedValue <= pointsPossibleValue
    }
    
    @MainActor
    private func saveGrade() async {
        guard let pointsPossibleValue = Double(pointsPossible),
              let pointsAwardedValue = Double(pointsAwarded) else {
            errorMessage = "Please enter valid numbers for points"
            return
        }
        
        guard pointsPossibleValue > 0 else {
            errorMessage = "Points possible must be greater than 0"
            return
        }
        
        guard pointsAwardedValue >= 0 && pointsAwardedValue <= pointsPossibleValue else {
            errorMessage = "Points awarded must be between 0 and \(String(format: "%.1f", pointsPossibleValue))"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            let updatedAssignment = try await api.updateAssignment(
                id: assignment.id,
                title: nil,
                workDates: assignment.workDates,
                dueDate: assignment.dueDate,
                instructions: nil,
                pointsPossible: pointsPossibleValue,
                pointsAwarded: pointsAwardedValue
            )
            
            onGradeSaved(updatedAssignment)
            dismiss()
        } catch {
            errorMessage = "Failed to save grade: \(error.localizedDescription)"
        }
        
        isSaving = false
    }
}

#Preview {
    let student = User(id: "preview-student", appleId: nil, name: "Test Student", email: "test@example.com", role: "student", familyId: "preview-family", createdAt: Date(), updatedAt: Date())
    let assignment = Assignment(
        id: "1",
        title: "Math Homework Chapter 5",
        studentId: student.id,
        dueDate: Date(),
        instructions: "Complete all problems on page 45",
        pointsPossible: 100,
        pointsAwarded: nil
    )
    
    AssignmentGradingView(
        assignment: assignment,
        courses: [],
        onGradeSaved: { _ in }
    )
}

