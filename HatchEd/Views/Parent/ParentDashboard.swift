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
    case subjects = "Subjects"
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
        case .subjects: return "book.closed"
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
        case .subjects: SubjectView()
        case .reportCard: ReportCard()
        case .portfolio: PortfolioView()
        case .resources: Resources()
        case .settings: Settings()
        case .dashboard: EmptyView() // Handled by setting selectedDestination to nil
        }
    }
}

struct ParentDashboard: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var dashboardVM = ParentDashboardViewModel()
    @State private var showingNameEditor = false
    @State private var editedName = ""
    @State private var showMenu = false
    @State private var showingAddChild = false
    @State private var addChildDidSucceed = false
    @State private var selectedDestination: NavigationDestination? = nil
    @State private var selectedNotification: Notification?
    
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
            dashboardVM.setAuthViewModel(authViewModel)
            authViewModel.updateUserFromDatabase()
            Task {
                await authViewModel.fetchNotifications()
                await dashboardVM.loadAssignmentsAndCourses()
            }
            dashboardVM.initializeAttendanceStatusIfNeeded(with: authViewModel.students)
            if authViewModel.currentUser?.name == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingNameEditor = true
                }
            }
        }
        .refreshable {
            await authViewModel.fetchNotifications()
            await dashboardVM.loadAssignmentsAndCourses()
        }
        .sheet(item: $dashboardVM.selectedAssignment) { assignment in
            AssignmentGradingView(
                assignment: assignment,
                courses: dashboardVM.courses,
                onGradeSaved: { _ in
                    Task { await dashboardVM.loadAssignmentsAndCourses() }
                }
            )
        }
        .onChange(of: authViewModel.students) { _, newValue in
            dashboardVM.initializeAttendanceStatusIfNeeded(with: newValue)
        }
        .sheet(item: $selectedNotification) { notification in
            NotificationDetailView(notification: notification) { toDelete in
                Task {
                    await authViewModel.deleteNotification(toDelete)
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
                    notifications: authViewModel.notifications,
                    onSelect: { selectedNotification = $0 }
                )
                completedAssignmentsSection
                attendanceSection
                addChildSection
                inspirationalQuoteSection
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
                        Button("Cancel") { showingNameEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let trimmed = editedName.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty { dashboardVM.updateUserName(trimmed) }
                            showingNameEditor = false
                        }
                        .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddChild) {
            AddChildView(didAddChild: $addChildDidSucceed)
        }
        .onChange(of: addChildDidSucceed) { _, newValue in
            if newValue {
                authViewModel.updateUserFromDatabase()
                addChildDidSucceed = false
            }
        }
    }
    
    private var addChildSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.badge.plus")
                    .foregroundColor(.hatchEdAccent)
                Text("Add Child")
                    .font(.headline)
                    .foregroundColor(.hatchEdText)
            }
            Text("Add a child to your family. They'll get a link to open the app and access their account.")
                .font(.subheadline)
                .foregroundColor(.hatchEdSecondaryText)
            Button(action: { showingAddChild = true }) {
                Label("Add Child", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.hatchEdAccent)
        }
    }
    
    private var welcomeSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome, \(authViewModel.currentUser?.name?.capitalized ?? "Parent!")")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.hatchEdText)
                Text("Manage your family's education")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if authViewModel.currentUser?.name == nil {
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
            
            if authViewModel.students.isEmpty {
                Text("No students linked yet.")
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.hatchEdCardBackground))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(authViewModel.students) { student in
                        NavigationLink(destination: StudentDetail(
                            student: student,
                            courses: dashboardVM.courses.filter { $0.students.contains(where: { $0.id == student.id }) },
                            assignments: dashboardVM.assignments.filter { $0.studentId == student.id }
                        )) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.hatchEdAccent)
                                    .font(.title3)
                                Text(student.name ?? "Student")
                                    .foregroundColor(.hatchEdText)
                                    .fontWeight(.medium)
                                if student.invitePending == true {
                                    Text("Pending")
                                        .font(.caption)
                                        .foregroundColor(.hatchEdSecondaryText)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.hatchEdSecondaryBackground))
                                }
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
                DatePicker("Attendance Date", selection: $dashboardVM.attendanceDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(.hatchEdAccent)
            }
            
            if dashboardVM.students.isEmpty {
                Text("Link students to start recording attendance.")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Button("Mark All Present") { dashboardVM.updateAttendanceStatusForAll(true) }
                            .buttonStyle(.bordered)
                            .tint(.hatchEdSuccess)
                        Button("Mark All Absent") { dashboardVM.updateAttendanceStatusForAll(false) }
                            .buttonStyle(.bordered)
                            .tint(.hatchEdCoralAccent)
                    }
                    ForEach(dashboardVM.students) { student in
                        AttendanceToggleRow(
                            name: student.name ?? "Student",
                            isPresent: Binding(
                                get: { dashboardVM.attendanceStatus[student.id] ?? true },
                                set: { dashboardVM.setAttendance(studentId: student.id, isPresent: $0) }
                            )
                        )
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Task { await dashboardVM.submitAttendance() }
                } label: {
                    HStack {
                        if dashboardVM.isSubmittingAttendance {
                            ProgressView()
                                .tint(.hatchEdWhite)
                        }
                        Text(dashboardVM.isSubmittingAttendance ? "Submitting..." : "Submit Attendance")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.hatchEdWhite)
                }
                .buttonStyle(.borderedProminent)
                .tint(.hatchEdAccent)
                .disabled(dashboardVM.isSubmittingAttendance || dashboardVM.students.isEmpty)
                switch dashboardVM.attendanceSubmissionState {
                case .idle: EmptyView()
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
        .animation(.easeInOut, value: dashboardVM.attendanceSubmissionState)
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
                if dashboardVM.isLoadingAssignments {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            if dashboardVM.pendingGradingAssignments.isEmpty && !dashboardVM.isLoadingAssignments {
                Text("No assignments pending grading.")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.hatchEdSecondaryBackground))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(dashboardVM.pendingGradingAssignments.prefix(5)) { assignment in
                        Button {
                            dashboardVM.selectedAssignment = assignment
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
                                        if let percentage = GradeHelper.percentage(pointsAwarded: pointsAwarded, pointsPossible: pointsPossible) {
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
    
    // MARK: - Inspirational Quote Section
    
    private var inspirationalQuoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "quote.opening")
                    .foregroundColor(.hatchEdAccent)
                Text("Daily Inspiration")
                    .font(.headline)
                    .foregroundColor(.hatchEdText)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Quote")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                Text("\"The beautiful thing about learning is that no one can take it away from you.\"")
                    .font(.body)
                    .italic()
                    .foregroundColor(.hatchEdText)
                Text("— B.B. King")
                    .font(.caption)
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.hatchEdAccentBackground)
        )
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
    let authViewModel = AuthViewModel()
    authViewModel.currentUser = User(id: "preview-user-id", appleId: "apple-id", name: "Jane Parent", email: "jane@example.com", role: "parent", familyId: nil)
    return ParentDashboard()
        .environmentObject(authViewModel)
}

