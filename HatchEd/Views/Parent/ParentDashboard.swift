//
//  ParentDashboard.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
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
            if signInManager.currentUser?.name == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingNameEditor = true
                }
            }
        }
    }
    
    // MARK: - Dashboard Content
    private var dashboardContent: some View {
        VStack {
            // Welcome
            HStack {
                Text("Welcome, \(signInManager.currentUser?.name?.capitalized ?? "Parent!")")
                    .font(.largeTitle)
                
                // Show edit button if name is missing
                if signInManager.currentUser?.name == nil {
                    Button(action: {
                        editedName = ""
                        showingNameEditor = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Notifications
            HStack {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.circle")
                        Spacer()
                        Text("Missing")
                        Spacer()
                        Button("X") {}
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Text("No new notifications")
                    
                    Spacer()
                    
                    Button("Complete") {}
                    
                    Spacer()
                }
            }
            
            // Students
            if signInManager.students.isEmpty {
                Text("No students linked yet.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(signInManager.students) { student in
                    NavigationLink(destination: StudentDetail(student: student)) {
                        HStack {
                            Text(student.name ?? "Student")
                        }
                    }
                }
                .navigationTitle(Text("Students"))
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
}

#Preview {
    let signInManager = AppleSignInManager()
    signInManager.currentUser = User(id: "preview-user-id", appleId: "apple-id", name: "Jane Parent", email: "jane@example.com", role: "parent", familyId: nil)
    return ParentDashboard()
        .environmentObject(signInManager)
}

