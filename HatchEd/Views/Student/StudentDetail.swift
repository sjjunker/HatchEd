//
//  StudentDetail.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/4/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct StudentDetail: View {
    @StateObject private var viewModel: StudentDetailViewModel
    @State private var viewModelState: StudentDetailViewModel.StateSnapshot
    @State private var hasLoadedAttendance = false
    @State private var fetchedInviteLink: String?
    @State private var fetchedInviteToken: String?
    @State private var isLoadingInvite = false

    init(student: User, courses: [Course] = [], assignments: [Assignment] = [], attendanceRecords: [AttendanceRecordDTO] = []) {
        let model = StudentDetailViewModel(student: student, courses: courses, assignments: assignments, attendanceRecords: attendanceRecords)
        let snapshot = model.makeSnapshot()
        _viewModel = StateObject(wrappedValue: model)
        _viewModelState = State(initialValue: snapshot)
    }

    init(viewModel: StudentDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _viewModelState = State(initialValue: viewModel.makeSnapshot())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if viewModel.student.invitePending == true {
                    invitePendingSection
                }
                attendanceSection
                attendanceHistorySection
                coursesSection
                recentAssignmentsSection
            }
            .padding()
        }
        .navigationTitle(viewModelState.studentName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModelState.updateToken) {
            viewModelState = viewModel.makeSnapshot()
        }
        .onAppear {
            guard !hasLoadedAttendance else { return }
            hasLoadedAttendance = true
            Task {
                await viewModel.loadAttendance()
                await MainActor.run {
                    viewModelState = viewModel.makeSnapshot()
                }
            }
        }
        .refreshable {
            await viewModel.loadAttendance()
            await MainActor.run {
                viewModelState = viewModel.makeSnapshot()
            }
        }
        .task(id: viewModel.student.id) {
            guard viewModel.student.invitePending == true else { return }
            let hasLink = viewModel.student.inviteLink != nil
            let hasToken = viewModel.student.inviteToken != nil && !(viewModel.student.inviteToken?.isEmpty ?? true)
            guard !hasLink && !hasToken else { return }
            isLoadingInvite = true
            defer { isLoadingInvite = false }
            do {
                let response = try await APIClient.shared.fetchChildInvite(childId: viewModel.student.id)
                fetchedInviteLink = response.inviteLink
                fetchedInviteToken = response.inviteToken
            } catch {
                // Leave fetched state nil; section will show nothing or loading
            }
        }
    }

    private var invitePendingSection: some View {
        Group {
            let link = viewModel.student.inviteLink ?? fetchedInviteLink
            let token = viewModel.student.inviteToken ?? fetchedInviteToken
            VStack(alignment: .leading, spacing: 8) {
                Text("Invite link")
                    .font(.headline)
                    .foregroundColor(.hatchEdText)
                if isLoadingInvite {
                    HStack {
                        ProgressView()
                            .tint(.hatchEdAccent)
                        Text("Loading…")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdSecondaryText)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdCardBackground))
                } else if let link, !link.isEmpty {
                    Text(link)
                        .font(.caption)
                        .foregroundColor(.hatchEdText)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdCardBackground))
                } else if let token, !token.isEmpty {
                    Text("hatched://invite?token=\(token)")
                        .font(.caption)
                        .foregroundColor(.hatchEdText)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdCardBackground))
                }
            }
        }
    }

    private var attendanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attendance")
                .font(.headline)
            HStack(alignment: .center, spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.hatchEdSecondaryBackground, lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: CGFloat(viewModelState.attendanceAverage))
                        .stroke(Color.hatchEdAccent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack {
                        Text(viewModelState.attendancePercentageString)
                            .font(.title.bold())
                        Text("Present")
                            .font(.caption)
                            .foregroundColor(.hatchEdSecondaryText)
                    }
                }
                .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 8) {
                    AttendanceRow(title: "Classes Attended", value: viewModelState.classesAttendedText)
                    AttendanceRow(title: "Classes Missed", value: viewModelState.classesMissedText)
                    AttendanceRow(title: "Attendance Streak", value: viewModelState.attendanceStreakText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdSecondaryBackground))

            switch viewModelState.attendanceStatus {
            case .loading:
                ProgressView("Loading attendance…")
                    .progressViewStyle(.linear)
                    .tint(.hatchEdAccent)
            case .error(let message):
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.hatchEdCoralAccent)
            case .loaded where viewModelState.attendanceRecords.isEmpty:
                Text("No attendance records yet.")
                    .font(.footnote)
                    .foregroundColor(.hatchEdSecondaryText)
            default:
                EmptyView()
            }
        }
    }

    private var attendanceHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModelState.attendanceRecords.isEmpty {
                Text("Attendance History")
                    .font(.headline)
                ForEach(viewModelState.attendanceRecords, id: \.id) { record in
                    AttendanceHistoryRow(record: record)
                }
            }
        }
    }

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Courses")
                .font(.headline)
            ForEach(viewModelState.courses) { course in
                CourseRow(course: course, studentId: viewModel.student.id)
            }
        }
    }

    private var recentAssignmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Assignments")
                .font(.headline)
            if viewModelState.recentAssignments.isEmpty {
                Text("No assignments completed recently.")
                    .foregroundColor(.hatchEdSecondaryText)
                    .font(.subheadline)
            } else {
                ForEach(viewModelState.recentAssignments) { assignment in
                    AssignmentRow(assignment: assignment)
                }
            }
        }
    }
}

private struct AttendanceRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.hatchEdSecondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.hatchEdText)
        }
    }
}

private struct AttendanceHistoryRow: View {
    let record: AttendanceRecordDTO
    
    private static let attendanceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private var formattedAttendanceDate: String {
        Self.attendanceDateFormatter.string(from: record.date)
    }

    var body: some View {
        HStack {
            Text(formattedAttendanceDate)
                .font(.subheadline)
                .foregroundColor(.hatchEdSecondaryText)
            Spacer()
            Text(record.status.capitalized)
                .font(.subheadline.bold())
                .foregroundColor(record.isPresent ? .hatchEdSuccess : .hatchEdCoralAccent)
        }
    }
}

private struct CourseRow: View {
    let course: Course
    let studentId: String

    private let gradeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    var body: some View {
        HStack {
            Text(course.name)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.hatchEdText)
            Spacer()
            if let grade = course.calculatedGrade(for: studentId) {
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

private struct AssignmentRow: View {
    let assignment: Assignment

    private var gradeFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.subheadline.bold())
                if let dueDate = assignment.dueDate {
                    Text(dueDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Show grade if assignment is completed
            if assignment.isCompleted {
                if let pointsAwarded = assignment.pointsAwarded,
                   let pointsPossible = assignment.pointsPossible,
                   pointsPossible > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f/%.0f", pointsAwarded, pointsPossible))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(gradeColor(for: pointsAwarded, possible: pointsPossible))
                        if let percentage = calculatePercentage(pointsAwarded: pointsAwarded, pointsPossible: pointsPossible),
                           let percentageText = gradeFormatter.string(from: NSNumber(value: percentage)) {
                            Text("\(percentageText)%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
    
    private func calculatePercentage(pointsAwarded: Double, pointsPossible: Double) -> Double? {
        guard pointsPossible > 0 else { return nil }
        return (pointsAwarded / pointsPossible) * 100
    }
    
    private func gradeColor(for pointsAwarded: Double, possible: Double) -> Color {
        guard possible > 0 else { return .primary }
        let percentage = (pointsAwarded / possible) * 100
        switch percentage {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        default: return .red
        }
    }
}

#Preview {
    let previewVM = StudentDetailViewModel.previewModel()
    return NavigationView {
        StudentDetail(viewModel: previewVM)
    }
}
