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
            }
            initializeAttendanceStatusIfNeeded(with: signInManager.students)
            if signInManager.currentUser?.name == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingNameEditor = true
                }
            }
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
            Text("Welcome, \(signInManager.currentUser?.name?.capitalized ?? "Parent!")")
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if signInManager.currentUser?.name == nil {
                Button(action: {
                    editedName = ""
                    showingNameEditor = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
        }
    }
    
    private var studentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Students")
                .font(.headline)
            
            if signInManager.students.isEmpty {
                Text("No students linked yet.")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(signInManager.students) { student in
                        NavigationLink(destination: StudentDetail(student: student)) {
                            HStack {
                                Text(student.name ?? "Student")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                        }
                    }
                }
            }
        }
    }
    
    private var attendanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Take Attendance")
                    .font(.headline)
                Spacer()
                DatePicker("Attendance Date", selection: $attendanceDate, displayedComponents: .date)
                    .labelsHidden()
            }
            
            if signInManager.students.isEmpty {
                Text("Link students to start recording attendance.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Button("Mark All Present") {
                            updateAttendanceStatusForAll(true)
                        }
                        .buttonStyle(.bordered)
                        Button("Mark All Absent") {
                            updateAttendanceStatusForAll(false)
                        }
                        .buttonStyle(.bordered)
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
                        }
                        Text(isSubmittingAttendance ? "Submitting..." : "Submit Attendance")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmittingAttendance || signInManager.students.isEmpty)
                
                switch attendanceSubmissionState {
                case .idle:
                    EmptyView()
                case .success(let message):
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.green)
                        .transition(.opacity)
                case .failure(let message):
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
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
}

private struct AttendanceToggleRow: View {
    let name: String
    @Binding var isPresent: Bool
    
    var body: some View {
        HStack {
            Text(name)
                .foregroundColor(.primary)
            Spacer()
            Toggle("Present", isOn: $isPresent)
                .labelsHidden()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

#Preview {
    let signInManager = AppleSignInManager()
    signInManager.currentUser = User(id: "preview-user-id", appleId: "apple-id", name: "Jane Parent", email: "jane@example.com", role: "parent", familyId: nil)
    return ParentDashboard()
        .environmentObject(signInManager)
}

