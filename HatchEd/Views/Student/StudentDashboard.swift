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
            Task {
                await signInManager.fetchNotifications()
            }
            if signInManager.currentUser?.name == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingNameEditor = true
                }
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
                // Other student-related content
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
}

