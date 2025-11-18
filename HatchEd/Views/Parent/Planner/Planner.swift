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
    @State private var selectedTask: PlannerTask?
    @State private var weekOffset: Int = 0
    @State private var assignments: [Assignment] = []
    @State private var isLoadingAssignments = false

    private let calendar = Calendar.current
    private let api = APIClient.shared

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 16) {
                header

                WeeklyOverviewView(
                    weekDates: currentWeekDates,
                    tasksProvider: { date in
                        let regularTasks = taskStore.tasks(for: date)
                        let assignmentTasks = assignmentsToTasks(for: date)
                        return regularTasks + assignmentTasks
                    },
                    onSelectDay: { date in
                        selectedDate = date
                        showingDaySheet = true
                    },
                    selectedDate: selectedDate,
                    onSelectTask: { task in
                        selectedTask = task
                    }
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
                    tasks: {
                        let regularTasks = taskStore.tasks(for: selectedDate)
                        let assignmentTasks = assignmentsToTasks(for: selectedDate)
                        return regularTasks + assignmentTasks
                    }(),
                    onDelete: { task in
                        // Only allow deletion of regular tasks, not assignments
                        if !task.id.hasPrefix("assignment-") {
                            taskStore.remove(task)
                        }
                    }
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
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(initialDate: selectedDate) { task in
                Task { @MainActor in
                    taskStore.add(task)
                }
            }
            .presentationDetents([.fraction(0.6), .large])
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheetView(
                task: task,
                assignment: assignmentForTask(task)
            )
            .presentationDetents([.fraction(0.7), .large])
        }
        .onAppear {
            Task {
                await loadAssignments()
            }
        }
        .refreshable {
            await loadAssignments()
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
    
    @MainActor
    private func loadAssignments() async {
        guard !isLoadingAssignments else { return }
        isLoadingAssignments = true
        do {
            assignments = try await api.fetchAssignments()
        } catch {
            print("Failed to load assignments: \(error)")
        }
        isLoadingAssignments = false
    }
    
    private func assignmentsToTasks(for date: Date) -> [PlannerTask] {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        
        return assignments
            .filter { assignment in
                guard let dueDate = assignment.dueDate else { return false }
                let dueDateStart = calendar.startOfDay(for: dueDate)
                return dueDateStart >= startOfDay && dueDateStart < endOfDay
            }
            .map { assignment in
                // Use due date at 3 PM (15:00) as default time, or start of day if not available
                let dueDate = assignment.dueDate ?? Date()
                let taskDate = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: dueDate) ?? calendar.startOfDay(for: dueDate)
                
                // Determine color based on subject, or use orange as default for assignments
                let colorName: String
                if let subject = assignment.subject {
                    // Map subject to a color - use first available color option
                    colorName = PlannerTask.colorOptions.first?.name ?? "Orange"
                } else {
                    colorName = "Orange" // Default color for assignments
                }
                
                return PlannerTask(
                    id: "assignment-\(assignment.id)",
                    title: assignment.title,
                    startDate: taskDate,
                    durationMinutes: 60, // Default 1 hour duration for assignments
                    colorName: colorName
                )
            }
    }
    
    private func assignmentForTask(_ task: PlannerTask) -> Assignment? {
        // Check if this is an assignment-based task
        guard task.id.hasPrefix("assignment-") else { return nil }
        
        // Extract assignment ID from task ID
        let assignmentId = String(task.id.dropFirst("assignment-".count))
        
        // Find the assignment in the assignments array
        return assignments.first { $0.id == assignmentId }
    }
}

#Preview {
    Planner()
}

