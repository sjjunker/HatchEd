//
//  ReportCard.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI

struct ReportCard: View {
    @EnvironmentObject private var signInManager: AppleSignInManager
    @State private var courses: [Course] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let api = APIClient.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if courses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 64))
                            .foregroundColor(.hatchEdSecondaryText)
                        Text("No courses found")
                            .font(.headline)
                            .foregroundColor(.hatchEdSecondaryText)
                        Text("Add courses in the Curriculum section to see report cards")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // Group courses by student
                    let coursesByStudent = Dictionary(grouping: courses) { $0.student.id }
                    
                    ForEach(signInManager.students) { student in
                        if let studentCourses = coursesByStudent[student.id], !studentCourses.isEmpty {
                            studentReportCard(student: student, courses: studentCourses)
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.hatchEdCoralAccent)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Report Cards")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await loadCourses()
            }
        }
        .refreshable {
            await loadCourses()
        }
        .background(Color.hatchEdBackground)
    }
    
    private func studentReportCard(student: User, courses: [Course]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Student Header
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.hatchEdAccent)
                    .font(.title2)
                Text(student.name ?? "Student")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.hatchEdText)
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hatchEdAccentBackground)
            )
            
            // Courses List
            VStack(spacing: 12) {
                ForEach(courses.sorted(by: { $0.name < $1.name })) { course in
                    CourseGradeRow(course: course)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.hatchEdCardBackground)
                .shadow(color: Color.hatchEdAccent.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    @MainActor
    private func loadCourses() async {
        isLoading = true
        errorMessage = nil
        do {
            courses = try await api.fetchCourses()
            // Calculate grade for each course based on its assignments
            courses = courses.map { course in
                var updatedCourse = course
                // Always calculate from assignments
                updatedCourse.grade = calculateCourseGrade(for: course)
                return updatedCourse
            }
        } catch {
            errorMessage = "Failed to load courses: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func calculateCourseGrade(for course: Course) -> Double? {
        // Filter to only graded assignments (have both pointsAwarded and pointsPossible)
        let gradedAssignments = course.assignments.filter { assignment in
            assignment.pointsAwarded != nil && assignment.pointsPossible != nil && assignment.pointsPossible! > 0
        }
        guard !gradedAssignments.isEmpty else { return nil }
        
        // Sum all pointsAwarded
        let totalPointsAwarded = gradedAssignments.reduce(0.0) { sum, assignment in
            sum + (assignment.pointsAwarded ?? 0)
        }
        
        // Sum all pointsPossible
        let totalPointsPossible = gradedAssignments.reduce(0.0) { sum, assignment in
            sum + (assignment.pointsPossible ?? 0)
        }
        
        guard totalPointsPossible > 0 else { return nil }
        
        // Calculate percentage: (total earned / total possible) * 100
        return (totalPointsAwarded / totalPointsPossible) * 100
    }
}

private struct CourseGradeRow: View {
    let course: Course
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.hatchEdText)
            }
            
            Spacer()
            
            if let grade = course.grade {
                Text(String(format: "%.1f%%", grade))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(gradeColor(for: grade))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(gradeColor(for: grade).opacity(0.15))
                    )
            } else {
                Text("No Grade")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.hatchEdSecondaryBackground)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdSecondaryBackground)
        )
    }
    
    private func gradeColor(for grade: Double) -> Color {
        if grade >= 90 {
            return .hatchEdSuccess
        } else if grade >= 70 {
            return .hatchEdWarning
        } else {
            return .hatchEdCoralAccent
        }
    }
}

