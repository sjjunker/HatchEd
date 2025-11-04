//
//  ParentDashboard.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//
import SwiftUI
import SwiftData

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
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject private var signInManager: AppleSignInManager
    @Query var user: [User]
    @State private var showingNameEditor = false
    @State private var editedName = ""
    @State private var showMenu = false
    @State private var selectedDestination: NavigationDestination? = nil
    
    // Fetch the current user from the database
    private var currentUserFromDB: User? {
        guard let userId = signInManager.currentUser?.id else { return nil }
        return user.first { $0.id == userId }
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
            if currentUserFromDB?.name == nil {
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
                Text("Welcome, \(currentUserFromDB?.name?.capitalized ?? "Parent!")")
                    .font(.largeTitle)
                
                // Show edit button if name is missing
                if currentUserFromDB?.name == nil {
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
            List(signInManager.currentUser?.family?.members ?? []) { student in
                NavigationLink(destination: StudentDetail(student: student)) {
                    HStack {
                        Text(student.name ?? "Student")
                    }
                }
            }
            .navigationTitle(Text("Students"))
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
                                if let user = currentUserFromDB {
                                    user.name = editedName.trimmingCharacters(in: .whitespaces)
                                    try? modelContext.save()
                                }
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: User.self, configurations: config)
    let context = container.mainContext
    
    // Create a mock user
    let mockUser = User(id: "preview-user-id", name: "Jane Parent", email: "jane@example.com")
    mockUser.role = "parent"
    context.insert(mockUser)
    
    // Create a mock sign-in manager
    let signInManager = AppleSignInManager(modelContext: context)
    signInManager.currentUser = mockUser
    
    return ParentDashboard()
        .environmentObject(signInManager)
        .modelContainer(container)
}

