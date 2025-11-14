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
            ForEach(viewModelState.subjectSections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.hatchEdAccent)
                    ForEach(section.courses) { course in
                        CourseRow(course: course)
                    }
                }
                Divider()
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

    var body: some View {
        HStack {
            Text(record.date, style: .date)
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

    private let gradeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    var body: some View {
        HStack {
            Text(course.name)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            if let grade = course.grade, let gradeText = gradeFormatter.string(from: NSNumber(value: grade)) {
                Text("\(gradeText)%")
                    .font(.headline)
                    .foregroundColor(gradeColor(for: grade))
            } else {
                Text("–")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private func gradeColor(for grade: Double) -> Color {
        switch grade {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        default: return .red
        }
    }
}

private struct AssignmentRow: View {
    let assignment: Assignment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(assignment.title)
                .font(.subheadline.bold())
            HStack {
                if let subject = assignment.subject?.name {
                    Text(subject)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let dueDate = assignment.dueDate {
                    Text(dueDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

#Preview {
    let previewVM = StudentDetailViewModel.previewModel()
    return NavigationView {
        StudentDetail(viewModel: previewVM)
    }
}
