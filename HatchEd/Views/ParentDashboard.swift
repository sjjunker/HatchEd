//
//  ParentDashboard.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//
import SwiftUI
import SwiftData

struct ParentDashboard: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject private var signInManager: AppleSignInManager
    @Query var user: [User]
    @State private var showingNameEditor = false
    @State private var editedName = ""
    
    // Fetch the current user from the database
    private var currentUserFromDB: User? {
        guard let userId = signInManager.currentUser?.id else { return nil }
        return user.first { $0.id == userId }
    }
    
    var body: some View {
        
            VStack {
                //Welcome
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
                                        // Update the user in database
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
                
                //Notifications
                HStack {
                    
                    //First
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
                        
                        Button("Complete") {
                          
                        }
                        
                        Spacer()
                    }
                }
                
                //Students
                /*List(signInManager.currentUser?.students ?? []) {student in
                    NavigationLink(destination: StudentDetail(student: student)) {
                        HStack {
                            Text(student.name ?? "Student")
                        }
                    }
                }
                .navigationTitle(Text("Students"))*/
            }
            .onAppear {
                // Sync currentUser with database
                signInManager.updateUserFromDatabase()
                // Show name editor if name is missing
                if currentUserFromDB?.name == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingNameEditor = true
                    }
                }
            }
    }
}

