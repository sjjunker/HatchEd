//
//  StudentDetail.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/4/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

private let studentDetailSectionIds = ["invitePending", "attendance", "attendanceHistory", "courses", "recentAssignments", "incompleteAssignments", "portfolios"]

struct StudentDetail: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel: StudentDetailViewModel
    @State private var viewModelState: StudentDetailViewModel.StateSnapshot
    @State private var hasLoadedAttendance = false
    @State private var hasLoadedPortfolios = false
    @State private var fetchedInviteLink: String?
    @State private var fetchedInviteToken: String?
    @State private var isLoadingInvite = false
    @State private var selectedIncompleteAssignment: Assignment?
    @StateObject private var sectionState = DashboardSectionState(storage: DashboardSectionStorage(
        orderKey: "studentDetailSectionOrder",
        hiddenKey: "studentDetailHiddenSections",
        defaultOrder: studentDetailSectionIds
    ))
    @State private var showingUnhideSheet = false

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
        List {
            ForEach(Array(sectionState.visibleSectionIds.enumerated()), id: \.element) { _, sectionId in
                sectionContent(for: sectionId)
            }
            .onMove(perform: sectionState.move)

            if !sectionState.hiddenSectionIds.isEmpty {
                Section {
                    Button {
                        showingUnhideSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.rectangle.on.folder")
                            Text("Show hidden sections (\(sectionState.hiddenSectionIds.count))")
                        }
                        .foregroundColor(.hatchEdAccent)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle(viewModelState.studentName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .task(id: viewModelState.updateToken) {
            viewModelState = viewModel.makeSnapshot()
        }
        .onAppear {
            Task {
                await viewModel.loadAssignments()
                await MainActor.run { viewModelState = viewModel.makeSnapshot() }
            }
            guard !hasLoadedAttendance else { return }
            hasLoadedAttendance = true
            Task {
                await viewModel.loadAttendance()
                await MainActor.run { viewModelState = viewModel.makeSnapshot() }
            }
            guard !hasLoadedPortfolios else { return }
            hasLoadedPortfolios = true
            Task {
                await viewModel.loadPortfolios()
                await MainActor.run { viewModelState = viewModel.makeSnapshot() }
            }
        }
        .refreshable {
            await viewModel.loadAssignments()
            await viewModel.loadAttendance()
            await viewModel.loadPortfolios()
            await MainActor.run { viewModelState = viewModel.makeSnapshot() }
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
                // Leave fetched state nil
            }
        }
        .sheet(item: $selectedIncompleteAssignment) { assignment in
            TaskDetailSheetView(
                task: createPlannerTaskFromAssignment(assignment),
                assignment: assignment,
                students: authViewModel.students,
                courses: viewModel.courses,
                onTaskUpdated: { _ in },
                onAssignmentUpdated: { updated in
                    viewModel.updateAssignment(updated)
                    viewModelState = viewModel.makeSnapshot()
                },
                onAssignmentDeleted: { deleted in
                    selectedIncompleteAssignment = nil
                    viewModel.removeAssignment(id: deleted.id)
                    viewModelState = viewModel.makeSnapshot()
                },
                onTaskDeleted: {}
            )
            .presentationDetents([.fraction(0.75), .large])
        }
        .sheet(isPresented: $showingUnhideSheet) {
            NavigationView {
                List {
                    ForEach(sectionState.hiddenSectionIdsArray, id: \.self) { sectionId in
                        Button {
                            withAnimation {
                                sectionState.unhideSection(sectionId)
                                if sectionState.hiddenSectionIds.isEmpty { showingUnhideSheet = false }
                            }
                        } label: {
                            HStack {
                                Text(studentDetailSectionTitle(for: sectionId))
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.hatchEdAccent)
                            }
                        }
                    }
                }
                .navigationTitle("Hidden Sections")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingUnhideSheet = false }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionContent(for sectionId: String) -> some View {
        sectionView(for: sectionId)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sectionState.hideSection(sectionId)
                    }
                } label: {
                    Label("Hide", systemImage: "eye.slash")
                }
            }
            .contextMenu {
                Button(role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sectionState.hideSection(sectionId)
                    }
                } label: {
                    Label("Hide Section", systemImage: "eye.slash")
                }
            }
    }

    @ViewBuilder
    private func sectionView(for sectionId: String) -> some View {
        switch sectionId {
        case "invitePending": invitePendingSection
        case "attendance": attendanceSection
        case "attendanceHistory": attendanceHistorySection
        case "courses": coursesSection
        case "recentAssignments": recentAssignmentsSection
        case "incompleteAssignments": incompleteAssignmentsSection
        case "portfolios": portfoliosSection
        default: EmptyView()
        }
    }

    private func createPlannerTaskFromAssignment(_ assignment: Assignment) -> PlannerTask {
        let startDate = assignment.dueDate ?? Date()
        let linkedCourse = assignment.courseId.flatMap { courseId in
            viewModel.courses.first { $0.id == courseId }
        }
        return PlannerTask(
            id: "assignment-due-\(assignment.id)",
            title: assignment.title,
            startDate: startDate,
            durationMinutes: assignment.workDurationsMinutes.first ?? 60,
            colorName: linkedCourse?.colorName ?? "Blue",
            subject: linkedCourse?.name,
            studentIds: [viewModel.student.id]
        )
    }

    private func studentDetailSectionTitle(for sectionId: String) -> String {
        switch sectionId {
        case "invitePending": return "Invite Link"
        case "attendance": return "Attendance"
        case "attendanceHistory": return "Attendance History"
        case "courses": return "Courses"
        case "recentAssignments": return "Recent Assignments"
        case "incompleteAssignments": return "Incomplete Assignments"
        case "portfolios": return "Portfolios"
        default: return sectionId
        }
    }

    private var invitePendingSection: some View {
        Group {
            if viewModel.student.invitePending != true {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invite link")
                        .font(.headline)
                        .foregroundColor(.hatchEdText)
                    Text("No invite pending.")
                        .font(.subheadline)
                        .foregroundColor(.hatchEdSecondaryText)
                }
            } else {
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdCardBackground))
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdCardBackground))
    }

    private var attendanceHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attendance History")
                .font(.headline)
            if viewModelState.attendanceRecords.isEmpty {
                Text("No attendance records yet.")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
            } else if let grouping = viewModelState.attendanceGrouping {
                // Current week: individual days
                if !grouping.currentWeekRecords.isEmpty {
                    Text("This Week")
                        .font(.subheadline.bold())
                        .foregroundColor(.hatchEdSecondaryText)
                    ForEach(grouping.currentWeekRecords, id: \.id) { record in
                        AttendanceHistoryRow(record: record)
                    }
                }
                // Monthly summaries
                ForEach(Array(grouping.monthlySummaries.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.month)
                            .font(.subheadline)
                            .foregroundColor(.hatchEdText)
                        Spacer()
                        Text("Total Days Present: \(item.daysPresent)")
                            .font(.subheadline.bold())
                            .foregroundColor(.hatchEdAccent)
                    }
                }
            } else {
                ForEach(viewModelState.attendanceRecords, id: \.id) { record in
                    AttendanceHistoryRow(record: record)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdCardBackground))
    }

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Courses")
                .font(.headline)
            ForEach(viewModelState.courses) { course in
                CourseRow(course: course, studentId: viewModel.student.id)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdCardBackground))
    }

    private var recentAssignmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Assignments")
                .font(.headline)
            if viewModelState.recentAssignmentsByMonth.isEmpty {
                Text("No assignments completed recently.")
                    .foregroundColor(.hatchEdSecondaryText)
                    .font(.subheadline)
            } else {
                ForEach(Array(viewModelState.recentAssignmentsByMonth.enumerated()), id: \.offset) { _, monthGroup in
                    DisclosureGroup {
                        ForEach(monthGroup.assignments) { assignment in
                            AssignmentRow(assignment: assignment)
                        }
                    } label: {
                        Text(monthGroup.month)
                            .font(.subheadline.bold())
                            .foregroundColor(.hatchEdText)
                    }
                    .accentColor(.hatchEdAccent)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdCardBackground))
    }

    private var incompleteAssignmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Incomplete Assignments")
                .font(.headline)
            if viewModelState.incompleteAssignments.isEmpty {
                Text("No ungraded assignments.")
                    .foregroundColor(.hatchEdSecondaryText)
                    .font(.subheadline)
            } else {
                ForEach(viewModelState.incompleteAssignments) { assignment in
                    Button {
                        selectedIncompleteAssignment = assignment
                    } label: {
                        HStack(spacing: 8) {
                            AssignmentRow(assignment: assignment)
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.hatchEdAccent)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdCardBackground))
    }

    private var portfoliosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Portfolios")
                .font(.headline)
            if viewModel.isLoadingPortfolios {
                ProgressView("Loading portfolios…")
                    .tint(.hatchEdAccent)
            } else if viewModelState.portfolios.isEmpty {
                Text("No portfolios yet.")
                    .foregroundColor(.hatchEdSecondaryText)
                    .font(.subheadline)
            } else {
                ForEach(viewModelState.portfolios) { portfolio in
                    NavigationLink(destination: PortfolioDetailView(portfolio: portfolio, isStudent: false)) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.hatchEdAccent)
                            Text(portfolio.designPattern.rawValue + " Portfolio")
                                .font(.subheadline.bold())
                                .foregroundColor(.hatchEdText)
                            if let created = portfolio.createdAt {
                                Spacer()
                                Text(created, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.hatchEdSecondaryText)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdCardBackground))
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
    let authVM = AuthViewModel()
    authVM.students = [previewVM.student]
    return NavigationView {
        StudentDetail(viewModel: previewVM)
            .environmentObject(authVM)
    }
}
