//
//  ParentDashboardViewModel.swift
//  HatchEd
//
//  MVVM: ViewModel for parent dashboard – assignments, courses, attendance.
//

import Foundation
import SwiftUI

/// Pure helper; not on any actor so it can be called from any context (views, tests).
enum GradeHelper {
    static func percentage(pointsAwarded: Double, pointsPossible: Double) -> Double? {
        guard pointsPossible > 0 else { return nil }
        return (pointsAwarded / pointsPossible) * 100
    }
}

enum AttendanceSubmissionState: Equatable {
    case idle
    case success(message: String)
    case failure(message: String)
}

@MainActor
final class ParentDashboardViewModel: ObservableObject {
    @Published private(set) var assignments: [Assignment] = []
    @Published private(set) var courses: [Course] = []
    @Published private(set) var isLoadingAssignments = false
    @Published private(set) var attendanceSubmissionState: AttendanceSubmissionState = .idle
    @Published private(set) var isSubmittingAttendance = false

    @Published var attendanceDate = Date()
    @Published var attendanceStatus: [String: Bool] = [:]
    @Published var selectedAssignment: Assignment?  // View sets this when user taps an assignment

    private let api = APIClient.shared
    private weak var authViewModel: AuthViewModel?

    var students: [User] {
        authViewModel?.students ?? []
    }

    var pendingGradingAssignments: [Assignment] {
        let today = Calendar.current.startOfDay(for: Date())
        return assignments.filter { assignment in
            if assignment.isCompleted { return false }
            guard let dueDate = assignment.dueDate else { return false }
            let dueDateStart = Calendar.current.startOfDay(for: dueDate)
            return dueDateStart <= today
        }
        .sorted { ($0.dueDate ?? Date()) > ($1.dueDate ?? Date()) }
    }

    var formattedAttendanceDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: attendanceDate)
    }

    func setAuthViewModel(_ auth: AuthViewModel) {
        authViewModel = auth
    }

    func loadAssignmentsAndCourses() async {
        guard !isLoadingAssignments else { return }
        isLoadingAssignments = true
        defer { isLoadingAssignments = false }
        do {
            async let assignmentsTask = api.fetchAssignments()
            async let coursesTask = api.fetchCourses()
            assignments = try await assignmentsTask
            courses = try await coursesTask
        } catch {
            print("Failed to load assignments/courses: \(error)")
        }
    }

    func initializeAttendanceStatusIfNeeded(with students: [User]) {
        guard !students.isEmpty else {
            attendanceStatus = [:]
            return
        }
        for student in students where attendanceStatus[student.id] == nil {
            attendanceStatus[student.id] = true
        }
    }

    func updateAttendanceStatusForAll(_ isPresent: Bool) {
        for student in students {
            attendanceStatus[student.id] = isPresent
        }
    }

    func setAttendance(studentId: String, isPresent: Bool) {
        attendanceStatus[studentId] = isPresent
    }

    func submitAttendance() async {
        guard !isSubmittingAttendance else { return }
        guard !students.isEmpty else {
            attendanceSubmissionState = .failure(message: "No students available to record attendance.")
            return
        }
        let statuses = students.reduce(into: [String: Bool]()) { partialResult, student in
            partialResult[student.id] = attendanceStatus[student.id] ?? true
        }
        isSubmittingAttendance = true
        attendanceSubmissionState = .idle
        do {
            guard let auth = authViewModel else {
                attendanceSubmissionState = .failure(message: "Session expired.")
                isSubmittingAttendance = false
                return
            }
            let response = try await auth.submitAttendance(date: attendanceDate, attendanceStatus: statuses)
            attendanceSubmissionState = .success(message: "Attendance saved for \(response.attendance.count) student(s) on \(formattedAttendanceDate).")
        } catch {
            attendanceSubmissionState = .failure(message: error.localizedDescription)
        }
        isSubmittingAttendance = false
    }

    func updateUserName(_ name: String) {
        authViewModel?.updateUserName(name)
    }
}
