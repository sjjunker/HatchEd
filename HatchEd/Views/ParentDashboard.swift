//
//  ParentDashboard.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
//
import SwiftUI

struct ParentDashboard: View {
    //  Get write access to SwiftData models using
    //  the environment's model context
    @Environment(\.modelContext) private var modelContext
    //  Fetch data from SwiftData using @Query
    //  @Query var students: [Student]
    
    var body: some View {
        VStack {
            Text("Welcome, Parent!")
                .font(.largeTitle)
            // Other parent-related content
        }
        .onAppear {
            // Load data specific to the parent user
        }
    }
}

