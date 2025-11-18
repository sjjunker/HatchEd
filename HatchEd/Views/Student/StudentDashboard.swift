//
//  ChildDashboard.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI

struct StudentDashboard: View {
    @EnvironmentObject var signInManager: AppleSignInManager
    @State private var showMenu = false
    @State private var selectedDestination: NavigationDestination? = nil
    @State private var showingNameEditor = false
    @State private var editedName = ""
    @State private var selectedNotification: Notification?
    @State private var assignments: [Assignment] = []
    @State private var completedAssignments: Set<String> = []
    @State private var isLoadingAssignments = false
    @State private var showingHelpConfirmation = false
    @State private var selectedAssignmentForHelp: Assignment?
    
    private let api = APIClient.shared
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            NavigationView {
                ZStack {
                    if let destination = selectedDestination, destination != .dashboard {
                        destination.view
                            .navigationTitle(destination.rawValue)
                    } else {
                        // Dashboard Content
                        studentDashboardContent
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
            loadCompletionStatus()
            Task {
                await signInManager.fetchNotifications()
                await loadDailyAssignments()
            }
            if signInManager.currentUser?.name == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingNameEditor = true
                }
            }
        }
        .refreshable {
            await signInManager.fetchNotifications()
            await loadDailyAssignments()
        }
        .alert("Request Help", isPresented: $showingHelpConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedAssignmentForHelp = nil
            }
            Button("Send Request") {
                if let assignment = selectedAssignmentForHelp {
                    Task {
                        await requestHelp(for: assignment)
                    }
                }
            }
        } message: {
            if let assignment = selectedAssignmentForHelp {
                Text("Send a help request to your parent for \"\(assignment.title)\"?")
            }
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
                            let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            signInManager.updateUserName(trimmed)
                            showingNameEditor = false
                        }
                        .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
    
    private var studentDashboardContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                welcomeSection
                NotificationsView(
                    notifications: signInManager.notifications,
                    onSelect: { selectedNotification = $0 }
                )
                dailyAssignmentsSection
                inspirationalQuoteSection
                if signInManager.isOffline {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.hatchEdWarning)
                        Text("Offline mode")
                            .font(.caption)
                            .foregroundColor(.hatchEdSecondaryText)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.hatchEdCardBackground)
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
    
    private var welcomeSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome, \(signInManager.currentUser?.name?.capitalized ?? "Student")!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.hatchEdText)
                Text("Track your progress and assignments")
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
    
    // MARK: - Daily Assignments Section
    
    private var dailyAssignmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(.hatchEdAccent)
                Text("Today's Assignments")
                    .font(.headline)
                    .foregroundColor(.hatchEdText)
                Spacer()
            }
            
            if isLoadingAssignments {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if dailyAssignments.isEmpty {
                Text("No assignments due today!")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(dailyAssignments) { assignment in
                    AssignmentRow(
                        assignment: assignment,
                        isCompleted: completedAssignments.contains(assignment.id),
                        onToggleComplete: {
                            toggleAssignmentCompletion(assignment)
                        },
                        onRequestHelp: {
                            selectedAssignmentForHelp = assignment
                            showingHelpConfirmation = true
                        }
                    )
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
    
    // MARK: - Helper Methods
    
    private var dailyAssignments: [Assignment] {
        let today = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: today) else {
            return []
        }
        
        return assignments.filter { assignment in
            guard let dueDate = assignment.dueDate else { return false }
            let dueDateStart = calendar.startOfDay(for: dueDate)
            return dueDateStart >= today && dueDateStart < endOfDay
        }
        .sorted { ($0.dueDate ?? Date()) < ($1.dueDate ?? Date()) }
    }
    
    @MainActor
    private func loadDailyAssignments() async {
        guard !isLoadingAssignments else { return }
        isLoadingAssignments = true
        do {
            assignments = try await api.fetchAssignments()
        } catch {
            print("Failed to load assignments: \(error)")
        }
        isLoadingAssignments = false
    }
    
    private func toggleAssignmentCompletion(_ assignment: Assignment) {
        if completedAssignments.contains(assignment.id) {
            completedAssignments.remove(assignment.id)
        } else {
            completedAssignments.insert(assignment.id)
        }
        // Save completion status to UserDefaults
        saveCompletionStatus()
    }
    
    private func saveCompletionStatus() {
        let array = Array(completedAssignments)
        UserDefaults.standard.set(array, forKey: "completedAssignments")
    }
    
    private func loadCompletionStatus() {
        if let array = UserDefaults.standard.array(forKey: "completedAssignments") as? [String] {
            completedAssignments = Set(array)
        }
    }
    
    @MainActor
    private func requestHelp(for assignment: Assignment) async {
        guard let currentUser = signInManager.currentUser,
              let familyId = currentUser.familyId else {
            print("Cannot request help: No current user or family ID")
            return
        }
        
        let studentName = currentUser.name ?? "Student"
        let notificationTitle = "Help Request"
        let notificationBody = "\(studentName) needs help with: \(assignment.title)"
        
        do {
            // Create notification request
            // The server should route this to all parent users in the family
            let request = CreateNotificationRequest(
                title: notificationTitle,
                body: notificationBody,
                userId: nil, // Server will route to parents in the family
                familyId: familyId
            )
            
            // Try to create notification via API
            // Note: This endpoint may need to be created on the server
            _ = try await api.request(
                Endpoint(path: "api/notifications", method: .post, body: request),
                responseType: NotificationResponse.self
            )
            
            // Refresh notifications
            await signInManager.fetchNotifications()
            
            // Show success feedback
            selectedAssignmentForHelp = nil
        } catch {
            print("Failed to send help request: \(error)")
            // Note: In production, you'd show an error alert to the user
        }
    }
}

// MARK: - Assignment Row View

private struct AssignmentRow: View {
    let assignment: Assignment
    let isCompleted: Bool
    let onToggleComplete: () -> Void
    let onRequestHelp: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .hatchEdSuccess : .hatchEdSecondaryText)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isCompleted ? .hatchEdSecondaryText : .hatchEdText)
                    .strikethrough(isCompleted)
                
                if let dueDate = assignment.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(dueDate, style: .time)
                            .font(.caption)
                    }
                    .foregroundColor(.hatchEdSecondaryText)
                }
                
                if let subject = assignment.subject {
                    Text(subject.name)
                        .font(.caption)
                        .foregroundColor(.hatchEdSecondaryText)
                }
            }
            
            Spacer()
            
            Button(action: onRequestHelp) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.hatchEdWarning)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCompleted ? Color.hatchEdSecondaryBackground.opacity(0.5) : Color.hatchEdCardBackground)
        )
    }
}

// MARK: - API Request Models

private struct CreateNotificationRequest: Encodable {
    let title: String
    let body: String
    let userId: String?
    let familyId: String
}

private struct NotificationResponse: Decodable {
    let notification: Notification
}

