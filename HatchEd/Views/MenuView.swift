//
//  MenuView.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//
import SwiftUI

struct MenuView: View {
    @Binding var selectedDestination: NavigationDestination?
    @Binding var showMenu: Bool
    @EnvironmentObject private var signInManager: AppleSignInManager
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
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            Text(item.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Sign Out Button
                Button(action: {
                    signInManager.signOut()
                    showMenu = false
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: "arrow.right.square")
                            .font(.title3)
                            .foregroundColor(.red)
                            .frame(width: 30)
                        
                        Text("Sign Out")
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(PlainListStyle())
            .onAppear {
                if let user = signInManager.currentUser {
                    menuManager.setMenuItems(user: user)
                }
            }
            .onChange(of: signInManager.currentUser) { _, newUser in
                if let user = newUser {
                    menuManager.setMenuItems(user: user)
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

