//
//  Settings.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/3/25.
//

import SwiftUI
import SwiftData

struct Settings: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject private var signInManager: AppleSignInManager
    @Query var families: [Family]
    
    @State private var showingCreateFamily = false
    @State private var showingJoinFamily = false
    @State private var newFamilyName = ""
    @State private var joinCode = ""
    
    private var currentUser: User? {
        signInManager.currentUser
    }
    
    private var isParent: Bool {
        currentUser?.role == "parent"
    }
    
    private var currentFamily: Family? {
        currentUser?.family
    }
    
    var body: some View {
        NavigationView {
            Form {
                if isParent {
                    familySection
                } else {
                    Text("Family settings are only available for parent accounts.")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingCreateFamily) {
            createFamilySheet
        }
        .sheet(isPresented: $showingJoinFamily) {
            joinFamilySheet
        }
    }
    
    // MARK: - Family Section
    
    private var familySection: some View {
        Section(header: Text("Family")) {
            if let family = currentFamily {
                // Display existing family info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Family Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(family.name)
                        .font(.body)
                    
                    Divider()
                    
                    Text("Join Code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(family.joinCode)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Divider()
                    
                    Text("Members: \(family.members.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                // No family - show options to create or join
                Button(action: {
                    showingCreateFamily = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create New Family")
                    }
                }
                
                Button(action: {
                    showingJoinFamily = true
                }) {
                    HStack {
                        Image(systemName: "person.2.badge.plus")
                        Text("Join Existing Family")
                    }
                }
            }
        }
    }
    
    // MARK: - Create Family Sheet
    
    private var createFamilySheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Create New Family")) {
                    TextField("Family Name", text: $newFamilyName)
                }
                
                Section(footer: Text("A unique join code will be generated for your family.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Create Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCreateFamily = false
                        newFamilyName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createFamily()
                    }
                    .disabled(newFamilyName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Join Family Sheet
    
    private var joinFamilySheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Join Family")) {
                    TextField("Enter Join Code", text: $joinCode)
                        .textInputAutocapitalization(.characters)
                }
                
                Section(footer: Text("Enter the 6-character join code provided by the family creator.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Join Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingJoinFamily = false
                        joinCode = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        joinFamily()
                    }
                    .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func createFamily() {
        guard let user = currentUser,
              isParent,
              !newFamilyName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        let family = Family(name: newFamilyName.trimmingCharacters(in: .whitespaces))
        user.family = family
        family.members.append(user)
        
        modelContext.insert(family)
        
        do {
            try modelContext.save()
            signInManager.updateUserFromDatabase()
            showingCreateFamily = false
            newFamilyName = ""
        } catch {
            print("Failed to create family: \(error.localizedDescription)")
        }
    }
    
    private func joinFamily() {
        guard let user = currentUser,
              isParent,
              !joinCode.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        let code = joinCode.trimmingCharacters(in: .whitespaces).uppercased()
        
        // Find family by join code
        let fetchDescriptor = FetchDescriptor<Family>(
            predicate: #Predicate { family in
                family.joinCode == code
            }
        )
        
        if let family = try? modelContext.fetch(fetchDescriptor).first {
            // Join the family
            user.family = family
            if !family.members.contains(where: { $0.id == user.id }) {
                family.members.append(user)
            }
            
            do {
                try modelContext.save()
                signInManager.updateUserFromDatabase()
                showingJoinFamily = false
                joinCode = ""
            } catch {
                print("Failed to join family: \(error.localizedDescription)")
            }
        } else {
            // Family not found - show error
            print("Family with join code \(code) not found")
            // You could add an alert here to show the error to the user
        }
    }
}
