//
//  Planner.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct Planner: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var taskStore = PlannerTaskStore()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showingDaySheet = false
    @State private var showingAddTask = false
    @State private var showingAddAssignment = false
    @State private var selectedTask: PlannerTask?
    @State private var weekOffset: Int = 0
    @State private var assignments: [Assignment] = []
    @State private var courses: [Course] = []
    @State private var isLoadingAssignments = false
    @State private var isLoadingCourses = false

    private let calendar = Calendar.current
    private let api = APIClient.shared

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 16) {
                header

                WeeklyOverviewView(
                    weekDates: currentWeekDates,
                    tasksProvider: { date in
                        // Only regular planner tasks (not assignments)
                        taskStore.tasks(for: date)
                    },
                    assignmentsProvider: { date in
                        // Only assignments for this day
                        assignmentsToTasks(for: date)
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
                // Force re-render when data changes by using the data as part of the view identity
                .id("planner-\(taskStore.tasks.count)-\(assignments.count)")
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
                        return (regularTasks + assignmentTasks).sorted { $0.startDate < $1.startDate }
                    }(),
                    onDelete: { task in
                        // Only allow deletion of regular tasks, not assignments
                        if !task.id.hasPrefix("assignment-") {
                            Task {
                                await taskStore.remove(task)
                            }
                        }
                    },
                    onTaskSelected: { task in
                        // Close day sheet and open task detail sheet
                        showingDaySheet = false
                        selectedTask = task
                    }
                )
                .presentationDetents([.fraction(0.4), .large])
            }

            Menu {
                Button {
                    showingAddTask = true
                } label: {
                    Label("Add Task", systemImage: "checkmark.circle")
                }
                
                Button {
                    showingAddAssignment = true
                } label: {
                    Label("Add Assignment", systemImage: "doc.text")
                }
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
            AddTaskView(
                initialDate: selectedDate,
                onSaveTask: { task in
                    Task { @MainActor in
                        taskStore.add(task)
                    }
                }
            )
            .presentationDetents([.fraction(0.65), .large])
        }
        .sheet(isPresented: $showingAddAssignment) {
            AddAssignmentView(
                initialDate: selectedDate,
                students: authViewModel.students,
                onSaveAssignment: { assignment in
                    upsertAssignment(assignment)
                }
            )
            .presentationDetents([.fraction(0.75), .large])
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheetView(
                task: task,
                assignment: assignmentForTask(task),
                students: authViewModel.students,
                courses: courses,
                onTaskUpdated: { updatedTask in
                    Task { @MainActor in
                        taskStore.upsert(updatedTask)
                    }
                },
                onAssignmentUpdated: { assignment in
                    upsertAssignment(assignment)
                },
                onTaskDeleted: {
                    Task {
                        await taskStore.refresh()
                    }
                }
            )
            .presentationDetents([.fraction(0.75), .large])
        }
        .task {
            // Load data when view appears
            await loadAssignments()
            await loadCourses()
            await taskStore.refresh()
        }
        .refreshable {
            await loadAssignments()
            await loadCourses()
            await taskStore.refresh()
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
        defer { isLoadingAssignments = false }
        
        do {
            assignments = try await api.fetchAssignments()
            print("Loaded \(assignments.count) assignments")
        } catch {
            print("Failed to load assignments: \(error)")
        }
    }
    
    @MainActor
    private func loadCourses() async {
        guard !isLoadingCourses else { return }
        isLoadingCourses = true
        do {
            courses = try await api.fetchCourses()
        } catch {
            print("Failed to load courses: \(error)")
        }
        isLoadingCourses = false
    }
    
    private func assignmentsToTasks(for date: Date) -> [PlannerTask] {
        return assignments
            .flatMap { assignment -> [PlannerTask] in
                let linkedCourseColor = assignment.courseId.flatMap { id in
                    courses.first(where: { $0.id == id })?.colorName
                }
                let workColor = linkedCourseColor ?? "Blue"
                var tasks: [PlannerTask] = []

                for (index, workDate) in assignment.workDates.enumerated() where calendar.isDate(workDate, inSameDayAs: date) {
                    tasks.append(
                        PlannerTask(
                            id: "assignment-work-\(assignment.id)::\(index)",
                            title: assignment.title,
                            startDate: workDate,
                            durationMinutes: 60,
                            colorName: workColor,
                            subject: assignment.courseId.flatMap { id in courses.first(where: { $0.id == id })?.name }
                        )
                    )
                }

                if let dueDate = assignment.dueDate, calendar.isDate(dueDate, inSameDayAs: date) {
                    tasks.append(
                        PlannerTask(
                            id: "assignment-due-\(assignment.id)",
                            title: "DUE: \(assignment.title)",
                            startDate: dueDate,
                            durationMinutes: 30,
                            colorName: "Red",
                            subject: assignment.courseId.flatMap { id in courses.first(where: { $0.id == id })?.name }
                        )
                    )
                }

                return tasks
            }
    }
    
    private func assignmentForTask(_ task: PlannerTask) -> Assignment? {
        guard task.id.hasPrefix("assignment-") else { return nil }
        let assignmentId: String
        if task.id.hasPrefix("assignment-work-") {
            let suffix = String(task.id.dropFirst("assignment-work-".count))
            assignmentId = suffix.components(separatedBy: "::").first ?? suffix
        } else if task.id.hasPrefix("assignment-due-") {
            assignmentId = String(task.id.dropFirst("assignment-due-".count))
        } else {
            assignmentId = String(task.id.dropFirst("assignment-".count))
        }
        return assignments.first { $0.id == assignmentId }
    }

    @MainActor
    private func upsertAssignment(_ assignment: Assignment) {
        if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
            assignments[index] = assignment
        } else {
            assignments.append(assignment)
        }
    }
}

#Preview {
    Planner()
}

