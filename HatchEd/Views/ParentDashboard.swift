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
    
    
    var body: some View {
            VStack {
                //Welcome
                Text("Welcome, \(signInManager.currentUser?.name?.capitalized ?? "Parent")!")
                    .font(.largeTitle)
                
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
    }
}

