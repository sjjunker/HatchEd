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
    
    let menuItems: [NavigationDestination] = [
        .dashboard,
        .planner,
        .studentList,
        .reportCard,
        .portfolio,
        .resources
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Menu Items
            List {
                ForEach(menuItems) { item in
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
        }
        .background(Color(UIColor.systemBackground))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

