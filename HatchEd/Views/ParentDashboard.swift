//
//  ParentDashboard.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//
import SwiftUI

struct ParentDashboard: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var signInManager: AppleSignInManager
    
    var body: some View {
        if let parent = signInManager.currentParent {
            VStack {
                Text("Welcome, \(parent.name ?? "Parent")!")
                    .font(.largeTitle)
                
                List(parent.students) {student in
                    NavigationLink(destination: StudentDetail(student: student)) {
                        HStack {
                            Text(student.name ?? "Student")
                        }
                    }
                }
                .navigationTitle(Text("Students"))
            }
        } else {
            Text("Please sign in.")
        }
    }
}

