//
//  ChildDashboard.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//
import SwiftUI

struct StudentDashboard: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var signInManager: AppleSignInManager
    @State private var showMenu = false
    @State private var selectedDestination: NavigationDestination? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                if let destination = selectedDestination {
                    destination.view
                        .navigationTitle(destination.rawValue)
                } else {
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
                        Image(systemName: showMenu ? "xmark" : "line.3.horizontal")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .animation(.easeInOut(duration: 0.3), value: showMenu)
                    }
                }
            }
            .overlay(
                Group {
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
            )
        }
        .onAppear {
            // Load data specific to the child user
        }
    }
    
    private var studentDashboardContent: some View {
        VStack {
            Text("Welcome, \(signInManager.currentUser?.name ?? "Child")!")
                .font(.largeTitle)
            // Other child-related content
        }
    }
}

