//
//  Planner.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct Planner: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var taskStore = PlannerTaskStore()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showingDaySheet = false
    @State private var showingAddTask = false
    @State private var showingAddAssignment = false
    @State private var showingAddActions = false
    @State private var selectedTask: PlannerTask?
    @State private var weekOffset: Int = 0
    @State private var selectedStudentFilterId: String? = nil
    @State private var assignments: [Assignment] = []
    @State private var courses: [Course] = []
    @State private var isLoadingAssignments = false
    @State private var isLoadingCourses = false
    @State private var showingPrintOptions = false
    @State private var printOptions = PlannerPrintOptions()
    @State private var printErrorMessage: String?
    @State private var plannerShareRequest: PlannerShareRequest?
    @State private var shouldGeneratePlannerExport = false

    private let calendar = Calendar.current
    private let api = APIClient.shared
    
    private var isStudentUser: Bool {
        authViewModel.currentUser?.role == "student"
    }
    
    private var currentStudentId: String? {
        authViewModel.currentUser?.id
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: isLandscape ? 4 : 16) {
                    header(isLandscape: isLandscape)

                    WeeklyOverviewView(
                        weekDates: currentWeekDates,
                        tasksProvider: { date in
                            filteredPlannerTasks(for: date)
                        },
                        assignmentsProvider: { date in
                            filteredAssignmentTasks(for: date)
                        },
                        onSelectDay: { date in
                            selectedDate = date
                            showingDaySheet = true
                        },
                        selectedDate: selectedDate,
                        onSelectTask: { task in
                            selectedTask = task
                        }
                    )
                    // Force re-render when data changes by using the data as part of the view identity
                    .id("planner-\(taskStore.tasks.count)-\(assignments.count)")
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { value in
                                if value.translation.width > 100 {
                                    // Swipe right - previous week
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        weekOffset -= 1
                                    }
                                } else if value.translation.width < -100 {
                                    // Swipe left - next week
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        weekOffset += 1
                                    }
                                }
                            }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if showingAddActions {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showingAddActions = false
                            }
                        }
                }
                
                VStack(alignment: .trailing, spacing: 10) {
                    if showingAddActions {
                        plannerAddActionsMenu
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingAddActions.toggle()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title)
                            .foregroundColor(.hatchEdWhite)
                            .padding()
                            .background(Color.hatchEdAccent)
                            .clipShape(Circle())
                            .shadow(radius: 6)
                    }
                }
                .padding()
            }
            .toolbar(isLandscape ? .hidden : .visible, for: .navigationBar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .horizontal)
        .sheet(isPresented: $showingDaySheet) {
            DayDetailSheetView(
                date: selectedDate,
                tasks: {
                    let regularTasks = filteredPlannerTasks(for: selectedDate)
                    let assignmentTasks = filteredAssignmentTasks(for: selectedDate)
                    return (regularTasks + assignmentTasks).sorted { $0.startDate < $1.startDate }
                }(),
                studentNamesById: Dictionary(
                    uniqueKeysWithValues: authViewModel.students.map { ($0.id, $0.name ?? "Student") }
                ),
                showsTaskStudents: !isStudentUser,
                onDelete: { task in
                    // Only allow deletion of regular tasks, not assignments
                    if !task.id.hasPrefix("assignment-") {
                        Task {
                            await taskStore.remove(task)
                        }
                    }
                },
                onTaskSelected: { task in
                    // Close day sheet and open task detail sheet
                    showingDaySheet = false
                    selectedTask = task
                }
            )
            .presentationDetents([.fraction(0.4), .large])
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(
                initialDate: selectedDate,
                students: availableStudentsForFilter,
                onSaveTask: { task in
                    Task { @MainActor in
                        taskStore.add(task)
                    }
                }
            )
            .presentationDetents([.fraction(0.65), .large])
        }
        .sheet(isPresented: $showingAddAssignment) {
            AddAssignmentView(
                initialDate: selectedDate,
                students: authViewModel.students,
                onSaveAssignment: { assignment in
                    upsertAssignment(assignment)
                }
            )
            .presentationDetents([.fraction(0.75), .large])
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheetView(
                task: task,
                assignment: assignmentForTask(task),
                students: authViewModel.students,
                courses: courses,
                onTaskUpdated: { updatedTask in
                    Task { @MainActor in
                        taskStore.upsert(updatedTask)
                    }
                },
                onAssignmentUpdated: { assignment in
                    upsertAssignment(assignment)
                },
                onTaskDeleted: {
                    Task {
                        await taskStore.refresh()
                    }
                }
            )
            .presentationDetents([.fraction(0.75), .large])
        }
        .sheet(isPresented: $showingPrintOptions, onDismiss: {
            guard shouldGeneratePlannerExport else { return }
            shouldGeneratePlannerExport = false
            Task { @MainActor in
                await exportPlannerAfterOptionsDismiss()
            }
        }) {
            PlannerPrintOptionsSheet(
                isStudentUser: isStudentUser,
                students: authViewModel.students,
                options: $printOptions,
                onCancel: {
                    showingPrintOptions = false
                },
                onPrint: {
                    showingPrintOptions = false
                    shouldGeneratePlannerExport = true
                }
            )
        }
        .background(
            PlannerActivityPresenter(
                request: $plannerShareRequest,
                onComplete: { error in
                    if let error {
                        printErrorMessage = "Unable to present share menu: \(error.localizedDescription)"
                    }
                }
            )
        )
        .task {
            // Load data when view appears
            if selectedStudentFilterId == nil, authViewModel.currentUser?.role == "student" {
                selectedStudentFilterId = authViewModel.currentUser?.id
            }
            await loadAssignments()
            await loadCourses()
            await taskStore.refresh()
        }
        .refreshable {
            await loadAssignments()
            await loadCourses()
            await taskStore.refresh()
        }
        .alert("Print Error", isPresented: Binding(
            get: { printErrorMessage != nil },
            set: { if !$0 { printErrorMessage = nil } }
        )) {
            Button("OK") { printErrorMessage = nil }
        } message: {
            if let printErrorMessage {
                Text(printErrorMessage)
            }
        }
    }

    private var plannerAddActionsMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                showingAddActions = false
                showingAddTask = true
            } label: {
                Label("Add Task", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            Divider()
            Button {
                showingAddActions = false
                showingAddAssignment = true
            } label: {
                Label("Add Assignment", systemImage: "doc.text")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            Divider()
            Button {
                showingAddActions = false
                printOptions.referenceDate = selectedDate
                printOptions.studentId = isStudentUser ? currentStudentId : selectedStudentFilterId
                showingPrintOptions = true
            } label: {
                Label("Print Planner", systemImage: "printer")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
        }
        .font(.subheadline)
        .foregroundColor(.hatchEdText)
        .frame(width: 210)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdCardBackground)
                .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
        )
    }

    @ViewBuilder
    private func header(isLandscape: Bool) -> some View {
        if isLandscape {
            HStack(spacing: 8) {
                weekNavigationControls(isCompact: true)
                if !isStudentUser && !availableStudentsForFilter.isEmpty {
                    studentFilterControl
                }
                todayControl
            }
            .padding(.horizontal)
            .padding(.top, 6)
        } else {
            VStack(spacing: 8) {
                weekNavigationControls(isCompact: false)
                HStack {
                    if !isStudentUser && !availableStudentsForFilter.isEmpty {
                        studentFilterControl
                    }
                    Spacer()
                    todayControl
                }
            }
            .padding(.horizontal)
            .padding(.top, 0)
        }
    }

    private func weekNavigationControls(isCompact: Bool) -> some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    weekOffset -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.hatchEdAccent)
                    .padding(8)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.hatchEdAccent)
                Text(weekTitle)
                    .font(isCompact ? .title2 : .title)
                    .fontWeight(.bold)
                    .foregroundColor(.hatchEdText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, isCompact ? 10 : 16)
            .padding(.vertical, isCompact ? 8 : 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hatchEdAccentBackground)
            )
            
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    weekOffset += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.hatchEdAccent)
                    .padding(8)
            }
        }
    }

    private var studentFilterControl: some View {
        Menu {
            Button {
                selectedStudentFilterId = nil
            } label: {
                Label("All Students", systemImage: selectedStudentFilterId == nil ? "checkmark" : "")
            }
            ForEach(availableStudentsForFilter) { student in
                Button {
                    selectedStudentFilterId = student.id
                } label: {
                    Label(student.name ?? "Student", systemImage: selectedStudentFilterId == student.id ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.hatchEdAccent)
                Text(selectedStudentFilterLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.hatchEdText)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.hatchEdSecondaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.hatchEdCardBackground)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.hatchEdSecondaryBackground, lineWidth: 1)
            )
        }
    }

    private var todayControl: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                weekOffset = 0
            }
        } label: {
            Text("Today")
                .font(.caption.weight(.semibold))
                .foregroundColor(.hatchEdAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.hatchEdCardBackground)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.hatchEdSecondaryBackground, lineWidth: 1)
                )
        }
    }
    
    private var weekTitle: String {
        let dates = currentWeekDates
        guard let firstDate = dates.first, let lastDate = dates.last else {
            return "This Week"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        if weekOffset == 0 {
            return "This Week"
        } else if calendar.isDate(firstDate, equalTo: lastDate, toGranularity: .year) {
            return "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
        }
    }

    private var currentWeekDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let currentWeekStart = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) ?? currentWeekStart
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: targetWeekStart) }
    }
    
    @MainActor
    private func loadAssignments() async {
        guard !isLoadingAssignments else { return }
        isLoadingAssignments = true
        defer { isLoadingAssignments = false }
        
        do {
            assignments = try await api.fetchAssignments()
            print("Loaded \(assignments.count) assignments")
        } catch {
            print("Failed to load assignments: \(error)")
        }
    }
    
    @MainActor
    private func loadCourses() async {
        guard !isLoadingCourses else { return }
        isLoadingCourses = true
        do {
            courses = try await api.fetchCourses()
        } catch {
            print("Failed to load courses: \(error)")
        }
        isLoadingCourses = false
    }
    
    private func assignmentsToTasks(for date: Date) -> [PlannerTask] {
        return assignments
            .flatMap { assignment -> [PlannerTask] in
                let linkedCourseColor = assignment.courseId.flatMap { id in
                    courses.first(where: { $0.id == id })?.colorName
                }
                let workColor = linkedCourseColor ?? "Blue"
                var tasks: [PlannerTask] = []

                for (index, workDate) in assignment.workDates.enumerated() where calendar.isDate(workDate, inSameDayAs: date) {
                    tasks.append(
                        PlannerTask(
                            id: "assignment-work-\(assignment.id)::\(index)",
                            title: assignment.title,
                            startDate: workDate,
                            durationMinutes: index < assignment.workDurationsMinutes.count ? max(15, assignment.workDurationsMinutes[index]) : 60,
                            colorName: workColor,
                            subject: assignment.courseId.flatMap { id in courses.first(where: { $0.id == id })?.name },
                            studentIds: [assignment.studentId]
                        )
                    )
                }

                if let dueDate = assignment.dueDate, calendar.isDate(dueDate, inSameDayAs: date) {
                    tasks.append(
                        PlannerTask(
                            id: "assignment-due-\(assignment.id)",
                            title: "DUE: \(assignment.title)",
                            startDate: dueDate,
                            durationMinutes: 30,
                            colorName: workColor,
                            subject: assignment.courseId.flatMap { id in courses.first(where: { $0.id == id })?.name },
                            studentIds: [assignment.studentId]
                        )
                    )
                }

                return tasks
            }
    }

    private func filteredPlannerTasks(for date: Date) -> [PlannerTask] {
        taskStore.tasks(for: date).filter { task in
            if isStudentUser, let currentStudentId {
                return task.studentIds.contains(currentStudentId)
            }
            guard let selectedStudentFilterId else { return true }
            return task.studentIds.isEmpty || task.studentIds.contains(selectedStudentFilterId)
        }
    }

    private func filteredAssignmentTasks(for date: Date) -> [PlannerTask] {
        assignmentsToTasks(for: date).filter { task in
            if isStudentUser, let currentStudentId {
                guard let assignment = assignmentForTask(task) else { return false }
                return assignment.studentId == currentStudentId
            }
            guard let selectedStudentFilterId else { return true }
            guard let assignment = assignmentForTask(task) else { return true }
            return assignment.studentId == selectedStudentFilterId
        }
    }

    private var availableStudentsForFilter: [User] {
        if authViewModel.currentUser?.role == "student", let currentUser = authViewModel.currentUser {
            return [authViewModel.students.first(where: { $0.id == currentUser.id }) ?? currentUser]
        }
        return authViewModel.students
    }

    private var selectedStudentFilterLabel: String {
        guard let selectedStudentFilterId else { return "All Students" }
        return availableStudentsForFilter.first(where: { $0.id == selectedStudentFilterId })?.name ?? "Student"
    }
    
    private func assignmentForTask(_ task: PlannerTask) -> Assignment? {
        guard task.id.hasPrefix("assignment-") else { return nil }
        let assignmentId: String
        if task.id.hasPrefix("assignment-work-") {
            let suffix = String(task.id.dropFirst("assignment-work-".count))
            assignmentId = suffix.components(separatedBy: "::").first ?? suffix
        } else if task.id.hasPrefix("assignment-due-") {
            assignmentId = String(task.id.dropFirst("assignment-due-".count))
        } else {
            assignmentId = String(task.id.dropFirst("assignment-".count))
        }
        return assignments.first { $0.id == assignmentId }
    }

    private func tasksForPrint(on date: Date, scopedTo studentId: String?) -> [PlannerTask] {
        let regularTasks = taskStore.tasks(for: date).filter { task in
            guard let studentId else { return true }
            return task.studentIds.contains(studentId)
        }
        let assignmentTasks = assignmentsToTasks(for: date).filter { task in
            guard let studentId else { return true }
            return task.studentIds.first == studentId
        }
        return (regularTasks + assignmentTasks).sorted { $0.startDate < $1.startDate }
    }

    private func weekDates(for date: Date) -> [Date] {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -offset, to: startOfDay) ?? startOfDay
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func monthDates(for date: Date) -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return [calendar.startOfDay(for: date)]
        }
        let dayCount = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
        return (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    @MainActor
    private func printPlanner() async {
        guard let pdfData = generatePlannerPDFData() else { return }
        plannerShareRequest = PlannerShareRequest(items: [pdfData])
    }

    @MainActor
    private func exportPlannerAfterOptionsDismiss() async {
        // Presenting immediately after sheet dismissal can trigger UIKit reparenting warnings.
        try? await Task.sleep(nanoseconds: 300_000_000)
        await printPlanner()
    }

    private func generatePlannerPDFData() -> Data? {
        let studentNamesById = Dictionary(
            uniqueKeysWithValues: authViewModel.students.map { ($0.id, $0.name ?? "Student") }
        )
        let selectedStudentId = isStudentUser ? currentStudentId : printOptions.studentId
        let studentLabel: String = {
            if let id = selectedStudentId {
                return studentNamesById[id] ?? "Student"
            }
            return "All Students"
        }()

        let pdfCreator = PlannerPrintPDFCreator()
        let pdfData: Data

        switch printOptions.scope {
        case .daily:
            let day = calendar.startOfDay(for: printOptions.referenceDate)
            let dayTasks = tasksForPrint(on: day, scopedTo: selectedStudentId)
            pdfData = pdfCreator.createDailyPDF(
                date: day,
                tasks: dayTasks,
                studentNamesById: studentNamesById,
                studentScopeLabel: studentLabel
            )
        case .weekly:
            let dates = weekDates(for: printOptions.referenceDate)
            let tasksByDay = Dictionary(uniqueKeysWithValues: dates.map { day in
                (day, tasksForPrint(on: day, scopedTo: selectedStudentId))
            })
            pdfData = pdfCreator.createWeeklyPDF(
                weekDates: dates,
                tasksByDate: tasksByDay,
                studentNamesById: studentNamesById,
                studentScopeLabel: studentLabel
            )
        case .monthly:
            let dates = monthDates(for: printOptions.referenceDate)
            let tasksByDay = Dictionary(uniqueKeysWithValues: dates.map { day in
                (day, tasksForPrint(on: day, scopedTo: selectedStudentId))
            })
            pdfData = pdfCreator.createMonthlyPDF(
                monthDates: dates,
                tasksByDate: tasksByDay,
                studentNamesById: studentNamesById,
                studentScopeLabel: studentLabel
            )
        }

        guard !pdfData.isEmpty else {
            printErrorMessage = "Unable to generate planner PDF."
            return nil
        }
        return pdfData
    }


    @MainActor
    private func upsertAssignment(_ assignment: Assignment) {
        if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
            assignments[index] = assignment
        } else {
            assignments.append(assignment)
        }
    }
}

private enum PlannerPrintScope: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

private struct PlannerPrintOptions {
    var scope: PlannerPrintScope = .daily
    var referenceDate: Date = Date()
    var studentId: String? = nil
}

private struct PlannerPrintOptionsSheet: View {
    let isStudentUser: Bool
    let students: [User]
    @Binding var options: PlannerPrintOptions
    let onCancel: () -> Void
    let onPrint: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Print Layout")) {
                    Picker("Range", selection: $options.scope) {
                        ForEach(PlannerPrintScope.allCases) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Date")) {
                    DatePicker(
                        options.scope == .daily ? "Day" : (options.scope == .weekly ? "Week Of" : "Month Of"),
                        selection: $options.referenceDate,
                        displayedComponents: .date
                    )
                }

                if !isStudentUser {
                    Section(header: Text("Student Scope")) {
                        Picker("Student", selection: $options.studentId) {
                            Text("All Students").tag(nil as String?)
                            ForEach(students) { student in
                                Text(student.name ?? "Student").tag(student.id as String?)
                            }
                        }
                    }
                }

                Section(footer: Text("Daily prints in portrait. Weekly and monthly print in landscape.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Print Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue", action: onPrint)
                        .fontWeight(.semibold)
                        .foregroundColor(.hatchEdAccent)
                }
            }
        }
    }
}

private struct PlannerShareRequest: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct PlannerActivityPresenter: UIViewControllerRepresentable {
    @Binding var request: PlannerShareRequest?
    let onComplete: (Error?) -> Void

    final class Coordinator {
        var presentedRequestID: UUID?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let request else {
            context.coordinator.presentedRequestID = nil
            return
        }
        guard context.coordinator.presentedRequestID != request.id else { return }
        context.coordinator.presentedRequestID = request.id

        let controller = UIActivityViewController(activityItems: request.items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, error in
            DispatchQueue.main.async {
                self.request = nil
                onComplete(error)
            }
        }

        DispatchQueue.main.async {
            uiViewController.present(controller, animated: true)
        }
    }
}

private final class PlannerPrintPDFCreator {
    private let calendar = Calendar.current

    private let headerTitleAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.boldSystemFont(ofSize: 22),
        .foregroundColor: UIColor.label
    ]
    private let headerSubtitleAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 12),
        .foregroundColor: UIColor.secondaryLabel
    ]
    private let dayHeadingAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.boldSystemFont(ofSize: 15),
        .foregroundColor: UIColor.label
    ]
    private let itemTitleAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
        .foregroundColor: UIColor.label
    ]
    private let itemMetaAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 10),
        .foregroundColor: UIColor.secondaryLabel
    ]

    func createDailyPDF(date: Date, tasks: [PlannerTask], studentNamesById: [String: String], studentScopeLabel: String) -> Data {
        renderPDF(landscape: false) { context, _, contentRect in
            context.beginPage()
            var y = contentRect.minY
            y = drawHeader(
                title: "Daily Planner",
                subtitle: "\(date.formatted(date: .complete, time: .omitted)) • \(studentScopeLabel)",
                in: contentRect,
                y: y
            )
            y += 8

            if tasks.isEmpty {
                _ = drawWrappedText("No tasks scheduled.", attributes: itemMetaAttributes, in: contentRect, y: y)
                return
            }

            for task in tasks {
                let needed = estimatedHeight(for: task, in: contentRect.width)
                if y + needed > contentRect.maxY {
                    context.beginPage()
                    y = contentRect.minY
                }
                y = drawTask(task, studentNamesById: studentNamesById, in: contentRect, y: y)
            }
        }
    }

    func createWeeklyPDF(weekDates: [Date], tasksByDate: [Date: [PlannerTask]], studentNamesById: [String: String], studentScopeLabel: String) -> Data {
        let first = weekDates.first ?? Date()
        let last = weekDates.last ?? first
        return renderPDF(landscape: true) { context, _, contentRect in
            context.beginPage()
            var y = contentRect.minY
            y = drawHeader(
                title: "Weekly Planner",
                subtitle: "\(first.formatted(date: .abbreviated, time: .omitted)) - \(last.formatted(date: .abbreviated, time: .omitted)) • \(studentScopeLabel)",
                in: contentRect,
                y: y
            )
            y += 10

            let timeColumnWidth: CGFloat = 42
            let dayHeaderHeight: CGFloat = 24
            let gridRect = CGRect(
                x: contentRect.minX,
                y: y,
                width: contentRect.width,
                height: max(120, contentRect.maxY - y)
            )
            let dayHeaderRect = CGRect(
                x: gridRect.minX + timeColumnWidth,
                y: gridRect.minY,
                width: gridRect.width - timeColumnWidth,
                height: dayHeaderHeight
            )
            let timelineRect = CGRect(
                x: gridRect.minX + timeColumnWidth,
                y: gridRect.minY + dayHeaderHeight,
                width: gridRect.width - timeColumnWidth,
                height: gridRect.height - dayHeaderHeight
            )

            let dayWidth = dayHeaderRect.width / CGFloat(max(weekDates.count, 1))
            let today = calendar.startOfDay(for: Date())
            UIColor.secondarySystemBackground.setFill()
            UIBezierPath(rect: dayHeaderRect).fill()
            UIColor.separator.setStroke()
            UIBezierPath(rect: gridRect).stroke()

            for (index, day) in weekDates.enumerated() {
                let x = dayHeaderRect.minX + CGFloat(index) * dayWidth
                let dayRect = CGRect(x: x, y: dayHeaderRect.minY, width: dayWidth, height: dayHeaderRect.height)
                let isToday = calendar.isDate(day, inSameDayAs: today)
                let headerPillRect = dayRect.insetBy(dx: 3, dy: 2)
                let headerPill = UIBezierPath(roundedRect: headerPillRect, cornerRadius: 6)
                UIColor.white.setFill()
                headerPill.fill()
                UIColor.black.setStroke()
                headerPill.lineWidth = isToday ? 1.2 : 0.7
                headerPill.stroke()
                let dayText = day.formatted(.dateTime.weekday(.abbreviated).day())
                let dayTextAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: UIColor.label
                ]
                let dayTextBox = NSString(string: dayText).boundingRect(
                    with: CGSize(width: dayRect.width - 6, height: dayRect.height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: dayTextAttributes,
                    context: nil
                )
                let drawRect = CGRect(
                    x: dayRect.midX - dayTextBox.width / 2,
                    y: dayRect.midY - dayTextBox.height / 2,
                    width: dayTextBox.width,
                    height: dayTextBox.height
                )
                dayText.draw(in: drawRect, withAttributes: dayTextAttributes)
            }

            UIColor.separator.setStroke()
            for hour in 0...24 {
                let yLine = timelineRect.minY + CGFloat(hour) / 24.0 * timelineRect.height
                let path = UIBezierPath()
                path.move(to: CGPoint(x: timelineRect.minX, y: yLine))
                path.addLine(to: CGPoint(x: timelineRect.maxX, y: yLine))
                path.lineWidth = hour % 6 == 0 ? 0.9 : 0.5
                path.stroke()

                if hour < 24 {
                    let label = timeLabel(forHour: hour)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 8),
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                    label.draw(
                        in: CGRect(x: gridRect.minX + 2, y: yLine - 5, width: timeColumnWidth - 4, height: 10),
                        withAttributes: attrs
                    )
                }
            }

            for col in 0...weekDates.count {
                let x = timelineRect.minX + CGFloat(col) * dayWidth
                let path = UIBezierPath()
                path.move(to: CGPoint(x: x, y: dayHeaderRect.minY))
                path.addLine(to: CGPoint(x: x, y: timelineRect.maxY))
                path.lineWidth = 0.6
                path.stroke()
            }

            for (dayIndex, day) in weekDates.enumerated() {
                let dayTasks = (tasksByDate[day] ?? []).sorted { $0.startDate < $1.startDate }
                let slots = weeklySlots(for: dayTasks)
                for slot in slots {
                    let task = slot.primary
                    let components = calendar.dateComponents([.hour, .minute], from: task.startDate)
                    let startMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                    let durationMinutes = max(15, slot.tasks.map(\.durationMinutes).max() ?? task.durationMinutes)
                    let endMinutes = min(24 * 60, startMinutes + durationMinutes)
                    if startMinutes >= 24 * 60 || endMinutes <= 0 { continue }

                    let clampedStart = max(0, startMinutes)
                    let clampedEnd = max(clampedStart + 1, endMinutes)
                    let yStart = timelineRect.minY + CGFloat(clampedStart) / 1440.0 * timelineRect.height
                    let yEnd = timelineRect.minY + CGFloat(clampedEnd) / 1440.0 * timelineRect.height
                    let blockRect = CGRect(
                        x: timelineRect.minX + CGFloat(dayIndex) * dayWidth + 2,
                        y: yStart + 1,
                        width: dayWidth - 4,
                        height: max(12, yEnd - yStart - 2)
                    )

                    let isAssignment = task.id.hasPrefix("assignment-")
                    let fillColor = pdfColor(for: task.colorName)
                    let taskPath = UIBezierPath(roundedRect: blockRect, cornerRadius: 5)
                    fillColor.setFill()
                    taskPath.fill()
                    UIColor.black.setStroke()
                    taskPath.lineWidth = 0.9
                    taskPath.stroke()

                    let marker: String = slot.hasDueItem ? "DUE" : (slot.hasAssignment && slot.hasTask ? "MIX" : (isAssignment ? "ASG" : "TSK"))
                    let titleText: String
                    if slot.tasks.count > 1 {
                        titleText = "\(slot.tasks.count) items"
                    } else {
                        titleText = task.title
                    }
                    let title = "\(task.startDate.formatted(date: .omitted, time: .shortened)) \(marker) \(titleText)"
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 7.5, weight: .semibold),
                        .foregroundColor: UIColor.black
                    ]
                    let textRect = blockRect.insetBy(dx: 3, dy: 2)
                    (title as NSString).draw(in: textRect, withAttributes: attrs)
                }
            }
        }
    }

    func createMonthlyPDF(monthDates: [Date], tasksByDate: [Date: [PlannerTask]], studentNamesById: [String: String], studentScopeLabel: String) -> Data {
        let monthTitle = monthDates.first?.formatted(.dateTime.year().month(.wide)) ?? "Monthly Planner"
        return renderPDF(landscape: true) { context, _, contentRect in
            context.beginPage()
            var y = contentRect.minY
            y = drawHeader(
                title: "Monthly Planner",
                subtitle: "\(monthTitle) • \(studentScopeLabel)",
                in: contentRect,
                y: y
            )
            y += 10

            guard let firstDate = monthDates.first else { return }
            let weekdayHeaderHeight: CGFloat = 22
            let leadingOffset = weekdayOffset(forMonthStart: firstDate)
            let totalCells = leadingOffset + monthDates.count
            let weekRows = Int(ceil(Double(totalCells) / 7.0))
            let gridRect = CGRect(
                x: contentRect.minX,
                y: y,
                width: contentRect.width,
                height: max(200, contentRect.maxY - y)
            )
            let columnWidth = gridRect.width / 7.0
            let bodyHeight = gridRect.height - weekdayHeaderHeight
            let rowHeight = bodyHeight / CGFloat(max(weekRows, 1))
            let weekdaySymbols = weekdaySymbolsInDisplayOrder()
            let today = calendar.startOfDay(for: Date())

            UIColor.secondarySystemBackground.setFill()
            UIBezierPath(rect: CGRect(x: gridRect.minX, y: gridRect.minY, width: gridRect.width, height: weekdayHeaderHeight)).fill()

            for col in 0..<7 {
                let x = gridRect.minX + CGFloat(col) * columnWidth
                let labelRect = CGRect(x: x, y: gridRect.minY, width: columnWidth, height: weekdayHeaderHeight)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: UIColor.label
                ]
                let label = weekdaySymbols[col]
                let box = NSString(string: label).boundingRect(
                    with: CGSize(width: columnWidth - 4, height: weekdayHeaderHeight),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs,
                    context: nil
                )
                let drawRect = CGRect(
                    x: labelRect.midX - box.width / 2,
                    y: labelRect.midY - box.height / 2,
                    width: box.width,
                    height: box.height
                )
                label.draw(in: drawRect, withAttributes: attrs)
            }

            UIColor.separator.setStroke()
            for col in 0...7 {
                let x = gridRect.minX + CGFloat(col) * columnWidth
                let path = UIBezierPath()
                path.move(to: CGPoint(x: x, y: gridRect.minY))
                path.addLine(to: CGPoint(x: x, y: gridRect.maxY))
                path.lineWidth = 0.6
                path.stroke()
            }
            for row in 0...weekRows {
                let yLine = gridRect.minY + weekdayHeaderHeight + CGFloat(row) * rowHeight
                let path = UIBezierPath()
                path.move(to: CGPoint(x: gridRect.minX, y: yLine))
                path.addLine(to: CGPoint(x: gridRect.maxX, y: yLine))
                path.lineWidth = 0.6
                path.stroke()
            }
            UIBezierPath(rect: gridRect).stroke()

            for dayIndex in 0..<monthDates.count {
                let cellIndex = leadingOffset + dayIndex
                let row = cellIndex / 7
                let col = cellIndex % 7
                let cellRect = CGRect(
                    x: gridRect.minX + CGFloat(col) * columnWidth,
                    y: gridRect.minY + weekdayHeaderHeight + CGFloat(row) * rowHeight,
                    width: columnWidth,
                    height: rowHeight
                )
                let day = monthDates[dayIndex]
                if calendar.isDateInWeekend(day) {
                    UIColor.systemGray6.setFill()
                    UIBezierPath(rect: cellRect).fill()
                }
                let isToday = calendar.isDate(day, inSameDayAs: today)
                if isToday {
                    let highlightRect = cellRect.insetBy(dx: 1.5, dy: 1.5)
                    let highlight = UIBezierPath(roundedRect: highlightRect, cornerRadius: 5)
                    UIColor.white.setFill()
                    highlight.fill()
                }
                let dayNumber = calendar.component(.day, from: day)
                let dayAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: isToday ? UIColor.black : UIColor.label
                ]
                "\(dayNumber)".draw(in: CGRect(x: cellRect.minX + 4, y: cellRect.minY + 3, width: 24, height: 12), withAttributes: dayAttrs)

                let tasks = (tasksByDate[day] ?? []).sorted { $0.startDate < $1.startDate }
                let maxVisible = 3
                var lineY = cellRect.minY + 18
                let lineHeight: CGFloat = 10
                for task in tasks.prefix(maxVisible) {
                    let timePrefix = task.startDate.formatted(date: .omitted, time: .shortened)
                    let marker = task.id.hasPrefix("assignment-due-") ? "DUE" : (task.id.hasPrefix("assignment-") ? "ASG" : "TSK")
                    let shortText = "\(timePrefix) \(marker) \(task.title)"
                    let chipRect = CGRect(x: cellRect.minX + 3, y: lineY, width: cellRect.width - 6, height: lineHeight - 1)
                    let chipPath = UIBezierPath(roundedRect: chipRect, cornerRadius: 3)
                    let chipColor = pdfColor(for: task.colorName)
                    chipColor.setFill()
                    chipPath.fill()
                    UIColor.black.setStroke()
                    chipPath.lineWidth = 0.7
                    chipPath.stroke()
                    let textAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 6.5, weight: .semibold),
                        .foregroundColor: UIColor.black
                    ]
                    (shortText as NSString).draw(
                        in: CGRect(x: chipRect.minX + 3, y: chipRect.minY + 1, width: chipRect.width - 6, height: chipRect.height - 2),
                        withAttributes: textAttrs
                    )
                    lineY += lineHeight
                }
                if tasks.count > maxVisible {
                    let moreText = "+\(tasks.count - maxVisible) more"
                    let moreAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 7),
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                    moreText.draw(
                        in: CGRect(x: cellRect.minX + 10, y: lineY, width: cellRect.width - 12, height: lineHeight),
                        withAttributes: moreAttrs
                    )
                }
            }
        }
    }

    private func weekdaySymbolsInDisplayOrder() -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        let first = max(0, calendar.firstWeekday - 1)
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private func weekdayOffset(forMonthStart startDate: Date) -> Int {
        let weekday = calendar.component(.weekday, from: startDate)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private func pdfColor(for colorName: String) -> UIColor {
        _ = colorName
        return UIColor.white
    }

    private struct WeeklyPrintSlot {
        let key: Int
        let tasks: [PlannerTask]
        var primary: PlannerTask { tasks[0] }
        var hasDueItem: Bool { tasks.contains(where: { $0.id.hasPrefix("assignment-due-") }) }
        var hasAssignment: Bool { tasks.contains(where: { $0.id.hasPrefix("assignment-") }) }
        var hasTask: Bool { tasks.contains(where: { !$0.id.hasPrefix("assignment-") }) }
    }

    private func weeklySlots(for tasks: [PlannerTask]) -> [WeeklyPrintSlot] {
        var grouped: [Int: [PlannerTask]] = [:]
        for task in tasks {
            grouped[printTimeKey(for: task.startDate), default: []].append(task)
        }
        return grouped.keys.sorted().compactMap { key in
            guard let group = grouped[key], !group.isEmpty else { return nil }
            let sortedGroup = group.sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.id < rhs.id
                }
                return lhs.startDate < rhs.startDate
            }
            return WeeklyPrintSlot(key: key, tasks: sortedGroup)
        }
    }

    private func printTimeKey(for date: Date) -> Int {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let dayHash = ((components.year ?? 0) * 10000) + ((components.month ?? 0) * 100) + (components.day ?? 0)
        return dayHash * 10000 + ((components.hour ?? 0) * 100) + (components.minute ?? 0)
    }

    private func timeLabel(forHour hour: Int) -> String {
        let normalized = hour % 24
        if normalized == 0 { return "12 AM" }
        if normalized < 12 { return "\(normalized) AM" }
        if normalized == 12 { return "12 PM" }
        return "\(normalized - 12) PM"
    }

    private func renderPDF(landscape: Bool, draw: (_ context: UIGraphicsPDFRendererContext, _ pageRect: CGRect, _ contentRect: CGRect) -> Void) -> Data {
        let pageSize = landscape
            ? CGSize(width: 11 * 72.0, height: 8.5 * 72.0)
            : CGSize(width: 8.5 * 72.0, height: 11 * 72.0)
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let margin: CGFloat = 40
        let contentRect = pageRect.insetBy(dx: margin, dy: margin)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "HatchEd",
            kCGPDFContextAuthor as String: "HatchEd",
            kCGPDFContextTitle as String: "Planner"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        return renderer.pdfData { context in
            draw(context, pageRect, contentRect)
        }
    }

    private func drawHeader(title: String, subtitle: String, in rect: CGRect, y: CGFloat) -> CGFloat {
        var nextY = drawWrappedText(title, attributes: headerTitleAttributes, in: rect, y: y)
        nextY = drawWrappedText(subtitle, attributes: headerSubtitleAttributes, in: rect, y: nextY + 2)
        return nextY + 6
    }

    private func drawTask(_ task: PlannerTask, studentNamesById: [String: String], in rect: CGRect, y: CGFloat) -> CGFloat {
        let timeText = task.startDate.formatted(date: .omitted, time: .shortened)
        let durationText = durationString(task.durationMinutes)
        let prefix = task.id.hasPrefix("assignment-due-") ? "[Due]" : (task.id.hasPrefix("assignment-") ? "[Assignment]" : "[Task]")
        let titleLine = "\(timeText) • \(durationText) • \(prefix) \(task.title)"
        var nextY = drawWrappedText(titleLine, attributes: itemTitleAttributes, in: rect, y: y)

        var meta: [String] = []
        if let subject = task.subject, !subject.isEmpty { meta.append(subject) }
        let studentNames = task.studentIds.compactMap { studentNamesById[$0] }
        if !studentNames.isEmpty { meta.append(studentNames.joined(separator: ", ")) }
        if !meta.isEmpty {
            nextY = drawWrappedText(meta.joined(separator: " • "), attributes: itemMetaAttributes, in: rect, y: nextY)
        }
        return nextY + 6
    }

    private func drawWrappedText(_ text: String, attributes: [NSAttributedString.Key: Any], in rect: CGRect, y: CGFloat) -> CGFloat {
        let box = NSString(string: text).boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let drawRect = CGRect(x: rect.minX, y: y, width: rect.width, height: ceil(box.height) + 2)
        text.draw(in: drawRect, withAttributes: attributes)
        return drawRect.maxY
    }

    private func estimatedHeight(for task: PlannerTask, in width: CGFloat) -> CGFloat {
        let title = "\(task.startDate.formatted(date: .omitted, time: .shortened)) • \(durationString(task.durationMinutes)) • \(task.title)"
        let titleRect = NSString(string: title).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: itemTitleAttributes,
            context: nil
        )
        return ceil(titleRect.height) + 22
    }

    private func durationString(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remaining = minutes % 60
        if hours > 0 {
            return remaining == 0 ? "\(hours) hr" : "\(hours) hr \(remaining) min"
        }
        return "\(remaining) min"
    }
}

#Preview {
    Planner()
}

