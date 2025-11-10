//
//  Planner.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct Planner: View {
    @StateObject private var taskStore = PlannerTaskStore()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showingDaySheet = false
    @State private var showingAddTask = false

    private let calendar = Calendar.current

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 16) {
                header

                WeeklyOverviewView(
                    weekDates: currentWeekDates,
                    tasksProvider: { taskStore.tasks(for: $0) },
                    onSelectDay: { date in
                        selectedDate = date
                        showingDaySheet = true
                    },
                    selectedDate: selectedDate
                )

                Spacer()
            }
            .navigationTitle("Planner")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDaySheet) {
                DayDetailSheetView(
                    date: selectedDate,
                    tasks: taskStore.tasks(for: selectedDate),
                    onDelete: { taskStore.remove($0) }
                )
                .presentationDetents([.fraction(0.4), .large])
            }

            Button {
                showingAddTask = true
            } label: {
                Image(systemName: "plus")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(radius: 6)
            }
            .padding()
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(initialDate: selectedDate) { task in
                    Task { @MainActor in
                        taskStore.add(task)
                    }
                }
                .presentationDetents([.fraction(0.6), .large])
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("This Week")
                .font(.title)
                .fontWeight(.semibold)
            Text("Tap a day to see all tasks")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top)
    }

    private var currentWeekDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }
}

#Preview {
    Planner()
}

