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
    @State private var weekOffset: Int = 0

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
                .gesture(
                    DragGesture(minimumDistance: 50)
                        .onEnded { value in
                            if value.translation.width > 100 {
                                // Swipe right - previous week
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    weekOffset -= 1
                                }
                            } else if value.translation.width < -100 {
                                // Swipe left - next week
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    weekOffset += 1
                                }
                            }
                        }
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
                    .foregroundColor(.hatchEdWhite)
                    .padding()
                    .background(Color.hatchEdAccent)
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
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    weekOffset -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.hatchEdAccent)
                    .padding(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.hatchEdAccent)
                    Text(weekTitle)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.hatchEdText)
                }
                Text("Tap a day to see all tasks • Swipe to navigate weeks")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hatchEdAccentBackground)
            )
            
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    weekOffset += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.hatchEdAccent)
                    .padding(8)
            }
            
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    weekOffset = 0
                }
            } label: {
                Text("Today")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.hatchEdWhite)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.hatchEdAccent)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var weekTitle: String {
        let dates = currentWeekDates
        guard let firstDate = dates.first, let lastDate = dates.last else {
            return "This Week"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        if weekOffset == 0 {
            return "This Week"
        } else if calendar.isDate(firstDate, equalTo: lastDate, toGranularity: .year) {
            return "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
        }
    }

    private var currentWeekDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let currentWeekStart = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) ?? currentWeekStart
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: targetWeekStart) }
    }
}

#Preview {
    Planner()
}

