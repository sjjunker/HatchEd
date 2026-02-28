//
//  ChildDashboard.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI
import UserNotifications

struct StudentDashboard: View {
    @EnvironmentObject var authViewModel: AuthViewModel
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
    @State private var dailyQuote: DailyQuoteDTO?
    @State private var isLoadingQuote = false
    
    private let api = APIClient.shared
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            NavigationView {
                ZStack {
                    if let destination = selectedDestination, destination != .dashboard {
                        destination.view
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .navigationTitle(destination == .planner ? "" : destination.rawValue)
                    } else {
                        // Dashboard Content
                        studentDashboardContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .navigationTitle("Dashboard")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            .navigationViewStyle(.stack)
            
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
            updateOrientationLock(for: selectedDestination)
            authViewModel.updateUserFromDatabase()
            loadCompletionStatus()
            Task {
                await authViewModel.fetchNotifications()
                await loadDailyAssignments()
                await loadDailyQuote()
            }
            if authViewModel.currentUser?.name == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingNameEditor = true
                }
            }
        }
        .refreshable {
            await authViewModel.fetchNotifications()
            await loadDailyAssignments()
            await loadDailyQuote()
        }
        .onChange(of: selectedDestination) { _, newValue in
            updateOrientationLock(for: newValue)
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
                    await authViewModel.deleteNotification(toDelete)
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
                            authViewModel.updateUserName(trimmed)
                            showingNameEditor = false
                        }
                        .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func updateOrientationLock(for destination: NavigationDestination?) {
        if destination == .planner {
            AppDelegate.setOrientationLock(.allButUpsideDown)
        } else {
            AppDelegate.setOrientationLock(.portrait, rotateTo: .portrait)
        }
    }
    
    private var studentDashboardContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                welcomeSection
                NotificationsView(
                    notifications: authViewModel.notifications,
                    onSelect: { selectedNotification = $0 }
                )
                dailyAssignmentsSection
                inspirationalQuoteSection
                if authViewModel.isOffline {
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
                Text("Welcome, \(authViewModel.currentUser?.name?.capitalized ?? "Student")!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.hatchEdText)
                Text("Track your progress and assignments")
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
                        isCompleted: assignment.isCompleted || completedAssignments.contains(assignment.id),
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
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if isLoadingQuote && dailyQuote == nil {
                    ProgressView()
                        .tint(.hatchEdAccent)
                } else if let dailyQuote {
                    Text("\"\(dailyQuote.quote)\"")
                        .font(.body)
                        .italic()
                        .foregroundColor(.hatchEdText)
                    if let author = dailyQuote.author, !author.isEmpty {
                        Text("— \(author)")
                            .font(.caption)
                            .foregroundColor(.hatchEdSecondaryText)
                            .padding(.top, 4)
                    }
                    if let work = dailyQuote.work, !work.isEmpty {
                        Text(work)
                            .font(.caption2)
                            .foregroundColor(.hatchEdSecondaryText)
                    }
                } else {
                    Text("Unable to load today's quote.")
                        .font(.footnote)
                        .foregroundColor(.hatchEdSecondaryText)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.hatchEdCoralAccent.opacity(0.14))
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
    private func loadDailyQuote() async {
        guard !isLoadingQuote else { return }
        isLoadingQuote = true
        defer { isLoadingQuote = false }
        do {
            dailyQuote = try await api.fetchDailyQuote()
        } catch {
            dailyQuote = nil
            print("Failed to load daily quote: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func requestHelp(for assignment: Assignment) async {
        guard let currentUser = authViewModel.currentUser,
              let familyId = currentUser.familyId else {
            print("Cannot request help: No current user or family ID")
            return
        }
        
        let studentName = currentUser.name ?? "Student"
        let notificationTitle = "Help Request"
        let notificationBody = "\(studentName) needs help with: \(assignment.title)"
        
        do {
            // Create notification request for parents
            let request = CreateNotificationRequest(
                title: notificationTitle,
                body: notificationBody,
                userId: nil, // nil means send to all parents in family
                familyId: familyId
            )
            
            // Create notification via API
            // Server returns array of notifications when sending to family
            _ = try await api.request(
                Endpoint(path: "api/notifications", method: .post, body: request),
                responseType: NotificationsResponse.self
            )
            
            // Send local push notification
            sendLocalNotification(title: notificationTitle, body: notificationBody)
            
            // Refresh notifications
            await authViewModel.fetchNotifications()
            
            // Show success feedback
            selectedAssignmentForHelp = nil
        } catch {
            print("Failed to send help request: \(error)")
            // Note: In production, you'd show an error alert to the user
        }
    }
    
    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Send immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending local notification: \(error)")
            }
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

