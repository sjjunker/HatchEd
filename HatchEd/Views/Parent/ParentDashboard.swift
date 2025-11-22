//
//  ParentDashboard.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI

enum NavigationDestination: String, Identifiable {
    case planner = "Planner"
    case studentList = "Students"
    case curriculum = "Curriculum"
    case reportCard = "Report Cards"
    case portfolio = "Portfolio"
    case resources = "Resources"
    case settings = "Settings"
    case dashboard = "Dashboard"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .planner: return "calendar"
        case .studentList: return "person.2"
        case .curriculum: return "book.closed"
        case .reportCard: return "doc.text"
        case .portfolio: return "folder"
        case .resources: return "book"
        case .settings: return "gearshape"
        case .dashboard: return "house"
        }
    }
    
    @ViewBuilder
    var view: some View {
        switch self {
        case .planner: Planner()
        case .studentList: StudentList()
        case .curriculum: CurriculumView()
        case .reportCard: ReportCard()
        case .portfolio: Portfolio()
        case .resources: Resources()
        case .settings: Settings()
        case .dashboard: EmptyView() // Handled by setting selectedDestination to nil
        }
    }
}

struct ParentDashboard: View {
    @EnvironmentObject private var signInManager: AppleSignInManager
    @State private var showingNameEditor = false
    @State private var editedName = ""
    @State private var showMenu = false
    @State private var selectedDestination: NavigationDestination? = nil
    @State private var selectedNotification: Notification?
    @State private var attendanceDate = Date()
    @State private var attendanceStatus: [String: Bool] = [:]
    @State private var isSubmittingAttendance = false
    @State private var attendanceSubmissionState: AttendanceSubmissionState = .idle
    @State private var assignments: [Assignment] = []
    @State private var courses: [Course] = []
    @State private var isLoadingAssignments = false
    @State private var selectedAssignment: Assignment?
    @State private var showingAssignmentGrading = false
    
    private enum AttendanceSubmissionState: Equatable {
        case idle
        case success(message: String)
        case failure(message: String)
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                ZStack {
                    if let destination = selectedDestination, destination != .dashboard {
                        destination.view
                            .navigationTitle(destination.rawValue)
                    } else {
                        // Dashboard Content
                        dashboardContent
                            .navigationTitle("Dashboard")
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showMenu.toggle()
                            }
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .opacity(showMenu ? 0 : 1)
                                .animation(.easeInOut(duration: 0.3), value: showMenu)
                        }
                    }
                }
            }
            
            // Hamburger Menu Overlay - outside NavigationView
            if showMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showMenu = false
                        }
                    }
                
                HStack {
                    MenuView(
                        selectedDestination: $selectedDestination,
                        showMenu: $showMenu
                    )
                    .frame(width: 280)
                    .transition(.move(edge: .leading))
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            signInManager.updateUserFromDatabase()
            Task {
                await signInManager.fetchNotifications()
                await loadAssignmentsAndCourses()
            }
            initializeAttendanceStatusIfNeeded(with: signInManager.students)
            if signInManager.currentUser?.name == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingNameEditor = true
                }
            }
        }
        .refreshable {
            await signInManager.fetchNotifications()
            await loadAssignmentsAndCourses()
        }
        .sheet(item: $selectedAssignment) { assignment in
            AssignmentGradingView(
                assignment: assignment,
                courses: courses,
                onGradeSaved: { updatedAssignment in
                    Task {
                        await loadAssignmentsAndCourses()
                    }
                }
            )
        }
        .onChange(of: signInManager.students) { newStudents in
            initializeAttendanceStatusIfNeeded(with: newStudents)
        }
        .sheet(item: $selectedNotification) { notification in
            NotificationDetailView(notification: notification) { toDelete in
                Task {
                    await signInManager.deleteNotification(toDelete)
                    await MainActor.run {
                        selectedNotification = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Dashboard Content
    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                welcomeSection
                NotificationsView(
                    notifications: signInManager.notifications,
                    onSelect: { selectedNotification = $0 }
                )
                completedAssignmentsSection
                attendanceSection
                studentsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showingNameEditor) {
            NavigationView {
                Form {
                    Section(header: Text("Enter your name")) {
                        TextField("Name", text: $editedName)
                    }
                }
                .navigationTitle("Update Name")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingNameEditor = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if !editedName.trimmingCharacters(in: .whitespaces).isEmpty {
                                signInManager.updateUserName(editedName.trimmingCharacters(in: .whitespaces))
                            }
                            showingNameEditor = false
                        }
                        .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
    
    private var welcomeSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome, \(signInManager.currentUser?.name?.capitalized ?? "Parent!")")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.hatchEdText)
                Text("Manage your family's education")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if signInManager.currentUser?.name == nil {
                Button(action: {
                    editedName = ""
                    showingNameEditor = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.hatchEdWhite)
                        .font(.title2)
                        .padding(8)
                        .background(Color.hatchEdAccent)
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.hatchEdAccentBackground)
        )
    }
    
    private var studentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.hatchEdAccent)
                Text("Students")
                    .font(.headline)
                    .foregroundColor(.hatchEdText)
            }
            
            if signInManager.students.isEmpty {
                Text("No students linked yet.")
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdCardBackground))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(signInManager.students) { student in
                        NavigationLink(destination: StudentDetail(student: student)) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.hatchEdAccent)
                                    .font(.title3)
                                Text(student.name ?? "Student")
                                    .foregroundColor(.hatchEdText)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundColor(.hatchEdAccent)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.hatchEdCardBackground)
                                    .shadow(color: Color.hatchEdAccent.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var attendanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.hatchEdSuccess)
                Text("Take Attendance")
                    .font(.headline)
                    .foregroundColor(.hatchEdText)
                Spacer()
                DatePicker("Attendance Date", selection: $attendanceDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(.hatchEdAccent)
            }
            
            if signInManager.students.isEmpty {
                Text("Link students to start recording attendance.")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Button("Mark All Present") {
                            updateAttendanceStatusForAll(true)
                        }
                        .buttonStyle(.bordered)
                        .tint(.hatchEdSuccess)
                        Button("Mark All Absent") {
                            updateAttendanceStatusForAll(false)
                        }
                        .buttonStyle(.bordered)
                        .tint(.hatchEdCoralAccent)
                    }
                    
                    ForEach(signInManager.students) { student in
                        AttendanceToggleRow(
                            name: student.name ?? "Student",
                            isPresent: Binding(
                                get: { attendanceStatus[student.id] ?? true },
                                set: { attendanceStatus[student.id] = $0 }
                            )
                        )
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Button(action: submitAttendance) {
                    HStack {
                        if isSubmittingAttendance {
                            ProgressView()
                                .tint(.hatchEdWhite)
                        }
                        Text(isSubmittingAttendance ? "Submitting..." : "Submit Attendance")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.hatchEdWhite)
                }
                .buttonStyle(.borderedProminent)
                .tint(.hatchEdAccent)
                .disabled(isSubmittingAttendance || signInManager.students.isEmpty)
                
                switch attendanceSubmissionState {
                case .idle:
                    EmptyView()
                case .success(let message):
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.hatchEdSuccess)
                        .transition(.opacity)
                case .failure(let message):
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.hatchEdCoralAccent)
                        .transition(.opacity)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.hatchEdCardBackground)
                .shadow(color: Color.hatchEdSuccess.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .animation(.easeInOut, value: attendanceSubmissionState)
    }
    
    private func initializeAttendanceStatusIfNeeded(with students: [User]) {
        guard !students.isEmpty else {
            attendanceStatus = [:]
            return
        }
        for student in students where attendanceStatus[student.id] == nil {
            attendanceStatus[student.id] = true
        }
    }
    
    private func updateAttendanceStatusForAll(_ isPresent: Bool) {
        for student in signInManager.students {
            attendanceStatus[student.id] = isPresent
        }
    }
    
    private func submitAttendance() {
        guard !isSubmittingAttendance else { return }
        guard !signInManager.students.isEmpty else {
            attendanceSubmissionState = .failure(message: "No students available to record attendance.")
            return
        }
        let statuses = signInManager.students.reduce(into: [String: Bool]()) { partialResult, student in
            partialResult[student.id] = attendanceStatus[student.id] ?? true
        }
        isSubmittingAttendance = true
        attendanceSubmissionState = .idle
        Task {
            do {
                let response = try await signInManager.submitAttendance(date: attendanceDate, attendanceStatus: statuses)
                await MainActor.run {
                    isSubmittingAttendance = false
                    attendanceSubmissionState = .success(message: "Attendance saved for \(response.attendance.count) student(s) on \(formattedAttendanceDate).")
                }
            } catch {
                await MainActor.run {
                    isSubmittingAttendance = false
                    attendanceSubmissionState = .failure(message: error.localizedDescription)
                }
            }
        }
    }
    
    private var formattedAttendanceDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: attendanceDate)
    }
    
    // MARK: - Completed Assignments Section
    
    private var completedAssignmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.hatchEdSuccess)
                Text("Assignments Pending Grading")
                    .font(.headline)
                    .foregroundColor(.hatchEdText)
                Spacer()
                if isLoadingAssignments {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if pendingGradingAssignments.isEmpty && !isLoadingAssignments {
                Text("No assignments pending grading.")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.hatchEdSecondaryBackground))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(pendingGradingAssignments.prefix(5)) { assignment in
                        Button {
                            selectedAssignment = assignment
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(assignment.title)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.hatchEdText)
                                    
                                    HStack(spacing: 8) {
                                        if let dueDate = assignment.dueDate {
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar")
                                                    .font(.caption2)
                                                Text(dueDate, style: .date)
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                    .foregroundColor(.hatchEdSecondaryText)
                                }
                                
                                Spacer()
                                
                                if let pointsAwarded = assignment.pointsAwarded,
                                   let pointsPossible = assignment.pointsPossible,
                                   pointsPossible > 0 {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(String(format: "%.0f/%.0f", pointsAwarded, pointsPossible))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.hatchEdSuccess)
                                        if let percentage = calculatePercentage(pointsAwarded: pointsAwarded, pointsPossible: pointsPossible) {
                                            Text(String(format: "%.0f%%", percentage))
                                                .font(.caption2)
                                                .foregroundColor(.hatchEdSecondaryText)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.hatchEdSuccess.opacity(0.15))
                                    .cornerRadius(8)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundColor(.hatchEdAccent)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.hatchEdCardBackground)
                                    .shadow(color: Color.hatchEdAccent.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.hatchEdCardBackground)
        )
    }
    
    private var pendingGradingAssignments: [Assignment] {
        let today = Calendar.current.startOfDay(for: Date())
        return assignments.filter { assignment in
            // Show assignments that are due today or in the past
            guard let dueDate = assignment.dueDate else { return false }
            let dueDateStart = Calendar.current.startOfDay(for: dueDate)
            return dueDateStart <= today
        }
        .sorted { ($0.dueDate ?? Date()) > ($1.dueDate ?? Date()) }
    }
    
    @MainActor
    private func loadAssignmentsAndCourses() async {
        guard !isLoadingAssignments else { return }
        isLoadingAssignments = true
        let api = APIClient.shared
        do {
            async let assignmentsTask = api.fetchAssignments()
            async let coursesTask = api.fetchCourses()
            assignments = try await assignmentsTask
            courses = try await coursesTask
        } catch {
            print("Failed to load assignments/courses: \(error)")
        }
        isLoadingAssignments = false
    }
    
    private func calculatePercentage(pointsAwarded: Double, pointsPossible: Double) -> Double? {
        guard pointsPossible > 0 else { return nil }
        return (pointsAwarded / pointsPossible) * 100
    }
}

private struct AttendanceToggleRow: View {
    let name: String
    @Binding var isPresent: Bool
    
    var body: some View {
        HStack {
            Text(name)
                .foregroundColor(.hatchEdText)
            Spacer()
            Toggle("Present", isOn: $isPresent)
                .labelsHidden()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.hatchEdSecondaryBackground))
    }
}

#Preview {
    let signInManager = AppleSignInManager()
    signInManager.currentUser = User(id: "preview-user-id", appleId: "apple-id", name: "Jane Parent", email: "jane@example.com", role: "parent", familyId: nil)
    return ParentDashboard()
        .environmentObject(signInManager)
}

