//
//  StudentDetailViewModel.swift
//  HatchEd
//
//  Created by Cursor (ChatGPT) on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import Foundation

@MainActor
final class StudentDetailViewModel: ObservableObject {
    struct AttendanceSummary {
        let classesAttended: Int
        let classesMissed: Int
        let streakDays: Int

        var totalClasses: Int { classesAttended + classesMissed }

        var average: Double {
            guard totalClasses > 0 else { return 0 }
            return Double(classesAttended) / Double(totalClasses)
        }
    }


    @Published private(set) var student: User
    @Published private(set) var attendance: AttendanceSummary
    @Published private(set) var attendanceRecords: [AttendanceRecordDTO]
    @Published private(set) var courses: [Course]
    @Published private(set) var assignments: [Assignment]
    @Published private(set) var isLoadingAttendance = false
    @Published private(set) var attendanceError: String?

    struct StateSnapshot {
        let updateToken = UUID()
        let studentName: String
        let attendanceAverage: Double
        let attendancePercentageString: String
        let classesAttendedText: String
        let classesMissedText: String
        let attendanceStreakText: String
        let attendanceStatus: AttendanceStatus
        let attendanceRecords: [AttendanceRecordDTO]
        let courses: [Course]
        let recentAssignments: [Assignment]

        enum AttendanceStatus {
            case loading
            case loaded
            case error(String)
        }
    }

    private let api: APIClient

    init(student: User, courses: [Course] = [], assignments: [Assignment] = [], attendance: AttendanceSummary? = nil, attendanceRecords: [AttendanceRecordDTO] = [], api: APIClient = .shared) {
        self.student = student
        self.api = api
        self.courses = courses
        self.assignments = assignments
        self.attendanceRecords = attendanceRecords
        if let attendance {
            self.attendance = attendance
        } else if !attendanceRecords.isEmpty {
            self.attendance = AttendanceSummary.from(records: attendanceRecords)
        } else {
            self.attendance = AttendanceSummary(classesAttended: 0, classesMissed: 0, streakDays: 0)
        }
    }

    func loadAttendance(limit: Int? = 90) async {
        guard !isLoadingAttendance else { return }
        isLoadingAttendance = true
        attendanceError = nil
        do {
            let records = try await api.fetchAttendance(studentUserId: student.id, limit: limit)
            attendanceRecords = records
            attendance = AttendanceSummary.from(records: records)
        } catch {
            attendanceError = error.localizedDescription
        }
        isLoadingAttendance = false
    }

    func makeSnapshot() -> StateSnapshot {
        let attendanceStatus: StateSnapshot.AttendanceStatus
        if isLoadingAttendance {
            attendanceStatus = .loading
        } else if let attendanceError {
            attendanceStatus = .error(attendanceError)
        } else {
            attendanceStatus = .loaded
        }
        
        // Calculate grades for each course based on assignments
        let coursesWithCalculatedGrades = courses.map { course in
            var updatedCourse = course
            updatedCourse.grade = calculateCourseGrade(for: course)
            return updatedCourse
        }

        return StateSnapshot(
            studentName: student.name ?? "Student",
            attendanceAverage: attendanceAverage,
            attendancePercentageString: attendancePercentageString,
            classesAttendedText: classesAttendedText,
            classesMissedText: classesMissedText,
            attendanceStreakText: attendanceStreakText,
            attendanceStatus: attendanceStatus,
            attendanceRecords: attendanceRecords,
            courses: coursesWithCalculatedGrades,
            recentAssignments: recentAssignments
        )
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

    var attendanceAverage: Double {
        attendance.average
    }

    var attendancePercentageString: String {
        NumberFormatter.percentFormatter.string(from: NSNumber(value: attendanceAverage)) ?? "0%"
    }

    var classesAttendedText: String {
        "\(attendance.classesAttended)"
    }

    var classesMissedText: String {
        "\(attendance.classesMissed)"
    }

    var attendanceStreakText: String {
        attendance.streakDays > 0 ? "\(attendance.streakDays) day\(attendance.streakDays == 1 ? "" : "s")" : "No streak"
    }


    var recentAssignments: [Assignment] {
        assignments
            .filter { $0.isCompleted } // Only show completed assignments
            .sorted { ($0.dueDate ?? Date.distantPast) > ($1.dueDate ?? Date.distantPast) }
            .prefix(5)
            .map { $0 }
    }
}

private extension StudentDetailViewModel.AttendanceSummary {
    static func from(records: [AttendanceRecordDTO]) -> StudentDetailViewModel.AttendanceSummary {
        guard !records.isEmpty else {
            return StudentDetailViewModel.AttendanceSummary(classesAttended: 0, classesMissed: 0, streakDays: 0)
        }

        let attended = records.filter { $0.isPresent }.count
        let missed = records.filter { !$0.isPresent }.count

        let sortedRecords = records.sorted { $0.date > $1.date }
        var streak = 0
        for record in sortedRecords {
            if record.isPresent {
                streak += 1
            } else {
                break
            }
        }

        return StudentDetailViewModel.AttendanceSummary(classesAttended: attended, classesMissed: missed, streakDays: streak)
    }
}

extension StudentDetailViewModel {
    static func previewModel() -> StudentDetailViewModel {
        let sample = SampleData.make()
        return StudentDetailViewModel(
            student: sample.student,
            courses: sample.courses,
            assignments: sample.assignments,
            attendanceRecords: sample.attendanceRecords
        )
    }
}

private enum SampleData {
    static func make() -> (student: User, courses: [Course], assignments: [Assignment], attendanceRecords: [AttendanceRecordDTO]) {
        let student = User(id: "preview-student", appleId: nil, name: "Alex Student", email: "alex@example.com", role: "student", familyId: "preview-family", createdAt: Date(), updatedAt: Date())

        let algebraAssignments = [
            Assignment(title: "Quadratic Functions", studentId: student.id, dueDate: Date().addingTimeInterval(-86_400), pointsPossible: 100, pointsAwarded: 92, questions: []),
            Assignment(title: "Polynomials Worksheet", studentId: student.id, dueDate: Date().addingTimeInterval(-259_200), pointsPossible: 100, pointsAwarded: 95, questions: [])
        ]

        let biologyAssignments = [
            Assignment(title: "Cell Structure Lab", studentId: student.id, dueDate: Date().addingTimeInterval(-172_800), pointsPossible: 100, pointsAwarded: 88, questions: []),
            Assignment(title: "Photosynthesis Quiz", studentId: student.id, dueDate: Date().addingTimeInterval(-604_800), pointsPossible: 100, pointsAwarded: 94, questions: [])
        ]

        let courses = [
            Course(name: "Algebra II", assignments: algebraAssignments, grade: 93.5, student: student),
            Course(name: "Biology", assignments: biologyAssignments, grade: 90.0, student: student)
        ]

        let assignments = (algebraAssignments + biologyAssignments).sorted { ($0.dueDate ?? .distantPast) > ($1.dueDate ?? .distantPast) }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today) ?? today

        let attendanceRecords: [AttendanceRecordDTO] = [
            AttendanceRecordDTO(id: UUID().uuidString, familyId: "preview-family", studentUserId: student.id, recordedByUserId: "parent", date: today, status: "present", isPresent: true, createdAt: today, updatedAt: today),
            AttendanceRecordDTO(id: UUID().uuidString, familyId: "preview-family", studentUserId: student.id, recordedByUserId: "parent", date: yesterday, status: "present", isPresent: true, createdAt: yesterday, updatedAt: yesterday),
            AttendanceRecordDTO(id: UUID().uuidString, familyId: "preview-family", studentUserId: student.id, recordedByUserId: "parent", date: twoDaysAgo, status: "absent", isPresent: false, createdAt: twoDaysAgo, updatedAt: twoDaysAgo)
        ]

        return (student, courses, assignments, attendanceRecords)
    }
}

private extension NumberFormatter {
    static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}
