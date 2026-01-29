//
//  MenuView.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI

struct MenuView: View {
    @Binding var selectedDestination: NavigationDestination?
    @Binding var showMenu: Bool
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var menuManager: MenuManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Menu Items
            List {
                ForEach(menuManager.menuItems) { item in
                    Button(action: {
                        // Set to nil for dashboard to show main content
                        selectedDestination = (item == .dashboard) ? nil : item
                        withAnimation {
                            showMenu = false
                        }
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: item.icon)
                                .font(.title3)
                                .foregroundColor(.hatchEdAccent)
                                .frame(width: 30)
                            
                            Text(item.rawValue)
                                .foregroundColor(.hatchEdText)
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Sign Out Button
                Button(action: {
                    authViewModel.signOut()
                    showMenu = false
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: "arrow.right.square")
                            .font(.title3)
                            .foregroundColor(.hatchEdCoralAccent)
                            .frame(width: 30)
                        
                        Text("Sign Out")
                            .foregroundColor(.hatchEdCoralAccent)
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(PlainListStyle())
            .onAppear {
                if let user = authViewModel.currentUser {
                    menuManager.setMenuItems(user: user)
                } else {
                    menuManager.menuItems = []
                }
            }
            .onChange(of: authViewModel.currentUser) { _, newUser in
                if let user = newUser {
                    menuManager.setMenuItems(user: user)
                } else {
                    menuManager.menuItems = []
                }
            }
        }
        .background(Color.hatchEdBackground)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

