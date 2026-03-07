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
    @Published private(set) var portfolios: [Portfolio] = []
    @Published private(set) var isLoadingAttendance = false
    @Published private(set) var attendanceError: String?
    @Published private(set) var isLoadingPortfolios = false

    struct AttendanceGrouping {
        let currentWeekRecords: [AttendanceRecordDTO]
        let monthlySummaries: [(month: String, daysPresent: Int)]
    }

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
        let attendanceGrouping: AttendanceGrouping?
        let courses: [Course]
        let recentAssignments: [Assignment]
        let recentAssignmentsByMonth: [(month: String, assignments: [Assignment])]
        let incompleteAssignments: [Assignment]
        let portfolios: [Portfolio]

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

    func updateAssignment(_ updated: Assignment) {
        guard let idx = assignments.firstIndex(where: { $0.id == updated.id }) else { return }
        assignments[idx] = updated
    }

    func removeAssignment(id: String) {
        assignments.removeAll { $0.id == id }
    }

    func loadAssignments() async {
        do {
            let all = try await api.fetchAssignments()
            assignments = all.filter { $0.studentId == student.id }
        } catch {
            // Keep existing assignments on error
        }
    }

    func loadPortfolios() async {
        guard !isLoadingPortfolios else { return }
        isLoadingPortfolios = true
        defer { isLoadingPortfolios = false }
        do {
            let all = try await api.fetchPortfolios()
            portfolios = all.filter { $0.studentId == student.id }
        } catch {
            portfolios = []
        }
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
        
        return StateSnapshot(
            studentName: student.name ?? "Student",
            attendanceAverage: attendanceAverage,
            attendancePercentageString: attendancePercentageString,
            classesAttendedText: classesAttendedText,
            classesMissedText: classesMissedText,
            attendanceStreakText: attendanceStreakText,
            attendanceStatus: attendanceStatus,
            attendanceRecords: attendanceRecords,
            attendanceGrouping: attendanceGrouping,
            courses: courses,
            recentAssignments: recentAssignments,
            recentAssignmentsByMonth: recentAssignmentsByMonth,
            incompleteAssignments: incompleteAssignments,
            portfolios: portfolios
        )
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
            .filter { $0.isCompleted }
            .sorted { ($0.dueDate ?? Date.distantPast) > ($1.dueDate ?? Date.distantPast) }
    }

    var recentAssignmentsByMonth: [(month: String, assignments: [Assignment])] {
        let completed = assignments.filter { $0.isCompleted }
        let grouped = Dictionary(grouping: completed) { a -> DateComponents in
            Calendar.current.dateComponents([.year, .month], from: a.dueDate ?? a.createdAt ?? Date())
        }
        return grouped.keys
            .sorted { dc1, dc2 in
                guard let d1 = Calendar.current.date(from: dc1),
                      let d2 = Calendar.current.date(from: dc2) else { return false }
                return d1 > d2
            }
            .compactMap { dc -> (month: String, assignments: [Assignment])? in
                guard let date = Calendar.current.date(from: dc) else { return nil }
                let assignments = grouped[dc] ?? []
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return (formatter.string(from: date), assignments.sorted { ($0.dueDate ?? .distantPast) > ($1.dueDate ?? .distantPast) })
            }
    }

    var incompleteAssignments: [Assignment] {
        assignments
            .filter { !$0.isCompleted }
            .sorted { ($0.dueDate ?? Date.distantPast) < ($1.dueDate ?? Date.distantPast) }
    }

    var attendanceGrouping: AttendanceGrouping? {
        guard !attendanceRecords.isEmpty else { return nil }
        let cal = Calendar.current
        let now = Date()
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return AttendanceGrouping(currentWeekRecords: [], monthlySummaries: monthlyAttendanceSummaries)
        }
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? now

        let currentWeekRecords = attendanceRecords
            .filter { $0.date >= weekStart && $0.date < weekEnd }
            .sorted { $0.date > $1.date }

        // Monthly summaries include all records (current month total includes current week)
        let summaries = monthlyAttendanceSummaries
        return AttendanceGrouping(currentWeekRecords: currentWeekRecords, monthlySummaries: summaries)
    }

    private var monthlyAttendanceSummaries: [(month: String, daysPresent: Int)] {
        let cal = Calendar.current
        let byMonth = Dictionary(grouping: attendanceRecords) { r in
            cal.dateComponents([.year, .month], from: r.date)
        }
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        return byMonth.keys
            .sorted { dc1, dc2 in
                guard let d1 = cal.date(from: dc1), let d2 = cal.date(from: dc2) else { return false }
                return d1 > d2
            }
            .compactMap { dc -> (month: String, daysPresent: Int)? in
                guard let date = cal.date(from: dc) else { return nil }
                let records = byMonth[dc] ?? []
                let daysPresent = records.filter { $0.isPresent }.count
                return (monthFormatter.string(from: date), daysPresent)
            }
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
            Course(name: "Algebra II", assignments: algebraAssignments, students: [student]),
            Course(name: "Biology", assignments: biologyAssignments, students: [student])
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
