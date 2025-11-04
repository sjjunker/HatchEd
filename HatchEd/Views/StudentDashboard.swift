//
//  ChildDashboard.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//
import SwiftUI
import SwiftData

struct StudentDashboard: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var signInManager: AppleSignInManager
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
        }
    }
    
    private var studentDashboardContent: some View {
        VStack {
            Text("Welcome, \(signInManager.currentUser?.name?.capitalized ?? "Student")!")
                .font(.largeTitle)
            // Other student-related content
        }
    }
}

