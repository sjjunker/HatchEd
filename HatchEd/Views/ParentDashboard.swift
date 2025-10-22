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
            VStack {
                Text("Welcome, \(signInManager.currentUser?.name ?? "Parent")!")
                    .font(.largeTitle)
                
                
                List(signInManager.currentUser?.students ?? []) {student in
                    NavigationLink(destination: StudentDetail(student: student)) {
                        HStack {
                            Text(student.name ?? "Student")
                        }
                    }
                }
                .navigationTitle(Text("Students"))
            }
    }
}

