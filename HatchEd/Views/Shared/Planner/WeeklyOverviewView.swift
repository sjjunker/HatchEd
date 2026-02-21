//
//  WeeklyOverviewView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct WeeklyOverviewView: View {
    let weekDates: [Date]
    let tasksProvider: (Date) -> [PlannerTask]
    let assignmentsProvider: (Date) -> [PlannerTask]
    let onSelectDay: (Date) -> Void
    let onSelectTask: ((PlannerTask) -> Void)?
    let selectedDate: Date
    @State private var expandedTasksColumn: Int? = nil
    
    init(weekDates: [Date], tasksProvider: @escaping (Date) -> [PlannerTask], assignmentsProvider: @escaping (Date) -> [PlannerTask], onSelectDay: @escaping (Date) -> Void, selectedDate: Date, onSelectTask: ((PlannerTask) -> Void)? = nil) {
        self.weekDates = weekDates
        self.tasksProvider = tasksProvider
        self.assignmentsProvider = assignmentsProvider
        self.onSelectDay = onSelectDay
        self.selectedDate = selectedDate
        self.onSelectTask = onSelectTask
    }

    private let calendar = Calendar.current
    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "EEE"
        return formatter
    }()
    private let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter
    }()

    private let hours: [Int] = Array(6...22)
    private let columnWidth: CGFloat = 45
    private let rowHeight: CGFloat = 45

    var body: some View {
        ZStack(alignment: .topLeading) {
            // ScrollView containing scrollable content
            GeometryReader { geometry in
                ScrollView([.vertical], showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        // Time labels column (left side)
                        VStack(spacing: 0) {
                            // Empty space for header row
                            Color.clear
                                .frame(width: columnWidth, height: rowHeight)
                            
                            // Time labels
                            drawTimeLabels()
                        }
                        .padding(.top, rowHeight)
                        
                        // Grid, tasks, and assignments (offset to account for headers)
                        ZStack(alignment: .topLeading) {
                            drawGrid()
                            drawTasks()
                            drawAssignmentsList()
                        }
                        .frame(
                            width: columnWidth * CGFloat(weekDates.count),
                            height: rowHeight * CGFloat(hours.count) + 120 // Extra space for assignment list
                        )
                        .offset(x: columnWidth, y: rowHeight * 2)
                    }
                    .frame(
                        width: columnWidth + (columnWidth * CGFloat(weekDates.count)),
                        height: rowHeight + (rowHeight * CGFloat(hours.count)) + 120, // Extra space for assignments list
                        alignment: .topLeading
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color.hatchEdBackground)
            }
            
            // Sticky day headers overlay (stays visible when scrolling vertically)
            HStack(spacing: 0) {
                // Empty space for time column
                Color.clear
                    .frame(width: columnWidth, height: rowHeight)
                
                // Day headers
                drawDayHeaders()
            }
            .padding(.leading, columnWidth)
            .frame(height: rowHeight)
            .background(Color.hatchEdBackground)
            .zIndex(2)
        }
        .background(Color.hatchEdBackground)
    }

    private func drawGrid() -> some View {
        let width = columnWidth * CGFloat(weekDates.count)
        let height = rowHeight * CGFloat(hours.count)
        
        return Path { path in
            for row in 0...hours.count {
                let y = CGFloat(row) * rowHeight
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }

            for column in 0...weekDates.count {
                let x = CGFloat(column) * columnWidth
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
            }
        }
        .stroke(Color.hatchEdSecondaryBackground, lineWidth: 1)
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func drawTimeLabels() -> some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
                Text(hourFormatter.string(from: date))
                    .font(.caption2)
                    .foregroundColor(.hatchEdSecondaryText)
                    .frame(width: columnWidth, height: rowHeight, alignment: .topLeading)
                    .padding(.top, 4)
                    .padding(.leading, 8)
                    .background(Color.hatchEdBackground)
            }
        }
        .frame(width: columnWidth)
        .frame(height: rowHeight * CGFloat(hours.count))
    }

    private func drawDayHeaders() -> some View {
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                Button {
                    onSelectDay(date)
                } label: {
                    VStack(spacing: 6) {
                        Text(weekdayFormatter.string(from: date).uppercased())
                            .font(.caption)
                            .foregroundColor(isSelected ? .hatchEdWhite : .hatchEdSecondaryText)
                        Text(date.formatted(.dateTime.day()))
                            .font(.headline)
                            .foregroundColor(isSelected ? .hatchEdWhite : .hatchEdText)
                    }
                    .frame(width: columnWidth, height: rowHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.hatchEdAccent : Color.hatchEdSecondaryBackground)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func drawTasks() -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(weekDates.indices, id: \.self) { column in
                let date = weekDates[column]
                let tasks = tasksProvider(date)
                let regularTasks = tasks.filter { !$0.id.hasPrefix("assignment-") }
                let inScopeAssignments = assignmentsProvider(date).filter { isInVisibleHours($0.startDate) }
                TasksForDay(
                    date: date,
                    tasks: regularTasks + inScopeAssignments,
                    column: column,
                    columnWidth: columnWidth,
                    rowHeight: rowHeight,
                    hours: hours,
                    onExpansionChanged: { isExpanded in
                        if isExpanded {
                            expandedTasksColumn = column
                        } else if expandedTasksColumn == column {
                            expandedTasksColumn = nil
                        }
                    },
                    onSelectTask: onSelectTask
                )
                .zIndex(expandedTasksColumn == column ? 50 : 1)
            }
        }
    }
    
    private func drawAssignmentsList() -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(weekDates.indices, id: \.self) { column in
                let date = weekDates[column]
                let assignments = assignmentsProvider(date).filter { !isInVisibleHours($0.startDate) }
                
                if !assignments.isEmpty {
                    AssignmentsListForDay(
                        assignments: assignments,
                        column: column,
                        columnWidth: columnWidth,
                        rowHeight: rowHeight,
                        hours: hours,
                        onSelectTask: onSelectTask
                    )
                }
            }
        }
    }

    private func isInVisibleHours(_ date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let minutesSinceMidnight = hour * 60 + minute
        let visibleStart = 6 * 60
        let visibleEnd = 22 * 60
        return minutesSinceMidnight >= visibleStart && minutesSinceMidnight <= visibleEnd
    }
}

private struct TasksForDay: View {
    let date: Date
    let tasks: [PlannerTask]
    let column: Int
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let hours: [Int]
    let onExpansionChanged: (Bool) -> Void
    let onSelectTask: ((PlannerTask) -> Void)?
    @State private var expandedSlotKey: Int? = nil

    private var dayStart: Date {
        Calendar.current.startOfDay(for: date)
    }
    private var visibleStart: Date {
        Calendar.current.date(bySettingHour: hours.first ?? 6, minute: 0, second: 0, of: dayStart) ?? dayStart
    }
    private var visibleEnd: Date {
        Calendar.current.date(bySettingHour: (hours.last ?? 22) + 1, minute: 0, second: 0, of: dayStart) ?? dayStart
    }

    var body: some View {
        let slots = groupedSlots()
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(expandedSlotKey != nil)
                .onTapGesture {
                    if expandedSlotKey != nil {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            expandedSlotKey = nil
                        }
                    }
                }

            ForEach(slots, id: \.key) { slot in
                let rect = rectForSlot(slot)
                let isExpanded = expandedSlotKey == slot.key
                let isCluster = slot.tasks.count > 1

                Button {
                    if isCluster {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            expandedSlotKey = isExpanded ? nil : slot.key
                        }
                    } else if let single = slot.tasks.first {
                        onSelectTask?(single)
                    }
                } label: {
                    ZStack {
                        markerView(for: slot, isCluster: isCluster)

                        if isCluster && slot.markerKind != .mixed {
                            Text("\(slot.tasks.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(slot.primary.color.opacity(0.95))
                                )
                                .offset(x: 8, y: -8)
                        }
                    }
                    .frame(width: rect.width, height: max(rect.height, 24), alignment: .center)
                    .contentShape(Rectangle())
                    .shadow(color: slot.primary.color.opacity(isExpanded ? 0.45 : 0.22), radius: isExpanded ? 8 : 3, x: 0, y: 2)
                    .scaleEffect(isExpanded ? 1.08 : 1.0)
                }
                .buttonStyle(.plain)
                .zIndex(isExpanded ? 1000 : 100)
                .position(x: rect.midX, y: rect.midY)

                if isExpanded && isCluster {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(slot.tasks) { task in
                            Button {
                                onSelectTask?(task)
                            } label: {
                                HStack(spacing: 6) {
                                    dueAwareAssignmentSymbol(isDue: task.id.hasPrefix("assignment-due-"), baseColor: .white)
                                    Text(task.title)
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(task.color.opacity(0.88))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                    .frame(width: 170)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.hatchEdBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(slot.primary.color.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    )
                    .position(x: rect.maxX + 90, y: rect.minY + 14 + CGFloat(min(slot.tasks.count, 4)) * 10)
                    .zIndex(1001)
                }
            }
        }
        .onChange(of: expandedSlotKey) { _, newValue in
            onExpansionChanged(newValue != nil)
        }
    }

    private func rectForSlot(_ slot: TaskSlot) -> CGRect {
        let task = slot.primary
        let totalInterval = max(visibleEnd.timeIntervalSince(visibleStart), 60 * 60)
        let clampedStart = max(task.startDate, visibleStart)
        let maxDuration = slot.tasks.map(\.durationMinutes).max() ?? task.durationMinutes
        let clampedEnd = min(task.startDate.addingTimeInterval(TimeInterval(maxDuration * 60)), visibleEnd)
        let startOffset = clampedStart.timeIntervalSince(visibleStart)
        let duration = max(clampedEnd.timeIntervalSince(clampedStart), 30 * 60)
        let normalizedOffset = CGFloat(startOffset / totalInterval)
        let normalizedHeight = CGFloat(duration / totalInterval)
        let columnStart = CGFloat(column) * columnWidth
        let barWidth: CGFloat = columnWidth - 16
        let y = normalizedOffset * (rowHeight * CGFloat(hours.count))
        let height = normalizedHeight * (rowHeight * CGFloat(hours.count))
        return CGRect(x: columnStart + 8, y: y, width: barWidth, height: height)
    }
    
    private func timeKey(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let dayHash = ((components.year ?? 0) * 10000) + ((components.month ?? 0) * 100) + (components.day ?? 0)
        return dayHash * 10000 + ((components.hour ?? 0) * 100) + (components.minute ?? 0)
    }

    private func groupedSlots() -> [TaskSlot] {
        var grouped: [Int: [PlannerTask]] = [:]
        for task in tasks {
            grouped[timeKey(for: task.startDate), default: []].append(task)
        }

        return grouped.keys.sorted().compactMap { key in
            guard let group = grouped[key], !group.isEmpty else { return nil }
            let sortedGroup = group.sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.id < rhs.id
                }
                return lhs.startDate < rhs.startDate
            }
            return TaskSlot(key: key, tasks: sortedGroup)
        }
    }

    private struct TaskSlot {
        let key: Int
        let tasks: [PlannerTask]

        var primary: PlannerTask { tasks[0] }
        var hasDueItem: Bool { tasks.contains(where: { $0.id.hasPrefix("assignment-due-") }) }
        var hasAssignment: Bool { tasks.contains(where: { $0.id.hasPrefix("assignment-") }) }
        var hasTask: Bool { tasks.contains(where: { !$0.id.hasPrefix("assignment-") }) }
        var markerKind: MarkerKind {
            if hasAssignment && hasTask { return .mixed }
            return hasAssignment ? .assignment : .task
        }
    }

    private enum MarkerKind {
        case task
        case assignment
        case mixed
    }

    @ViewBuilder
    private func markerView(for slot: TaskSlot, isCluster: Bool) -> some View {
        let strokeColor = Color.clear
        switch slot.markerKind {
        case .task:
            Image(systemName: "checkmark.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(slot.primary.color)
                .frame(width: markerSize(for: slot).width, height: markerSize(for: slot).height)
        case .assignment:
            dueAwareAssignmentSymbol(isDue: slot.hasDueItem, baseColor: slot.primary.color)
                .frame(width: markerSize(for: slot).width, height: markerSize(for: slot).height)
        case .mixed:
            Capsule(style: .continuous)
                .fill(slot.primary.color.opacity(0.9))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(strokeColor, lineWidth: 2)
                )
                .overlay(
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                        dueAwareAssignmentSymbol(isDue: slot.hasDueItem, baseColor: .white.opacity(0.95))
                            .scaleEffect(0.55)
                        if isCluster {
                            Text("\(slot.tasks.count)")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                )
                .frame(width: markerSize(for: slot).width, height: markerSize(for: slot).height)
        }
    }

    private func markerSize(for slot: TaskSlot) -> CGSize {
        switch slot.markerKind {
        case .task:
            return CGSize(width: 17, height: 17)
        case .assignment:
            return CGSize(width: 17, height: 17)
        case .mixed:
            return CGSize(width: 24, height: 14)
        }
    }

    private func dueAwareAssignmentSymbol(isDue: Bool, baseColor: Color) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "doc.text")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(baseColor)
            if isDue {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.red)
                    .offset(x: 3, y: -3)
            }
        }
    }
}

private struct AssignmentsListForDay: View {
    let assignments: [PlannerTask]
    let column: Int
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let hours: [Int]
    let onSelectTask: ((PlannerTask) -> Void)?
    
    private var assignmentsListY: CGFloat {
        // Position at the end of the day (after the last hour row)
        return CGFloat(hours.count) * rowHeight + 8 // 8 points spacing after the grid
    }
    
    private var listHeight: CGFloat {
        // Calculate height based on number of assignments
        // Header (16) + spacing (8) + assignments (20 each) + padding
        let assignmentHeight: CGFloat = 20
        let headerHeight: CGFloat = 16
        let spacing: CGFloat = 8
        return headerHeight + spacing + (CGFloat(assignments.count) * assignmentHeight) + CGFloat(max(0, assignments.count - 1) * 4)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            Text("Assignments")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.hatchEdSecondaryText)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            
            // Assignment list
            ForEach(assignments) { assignment in
                let isDue = assignment.id.hasPrefix("assignment-due-")
                Button {
                    onSelectTask?(assignment)
                } label: {
                    HStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "doc.text.fill")
                                .font(.caption2)
                                .foregroundColor(assignment.color)
                            if isDue {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 7))
                                    .foregroundColor(.red)
                                    .offset(x: 3, y: -3)
                            }
                        }
                        .frame(width: 12)
                        
                        Text(assignment.title)
                            .font(.caption2)
                            .foregroundColor(.hatchEdText)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .frame(width: columnWidth - 12, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(assignment.color.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(assignment.color.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: columnWidth - 12, height: listHeight, alignment: .topLeading)
        .position(
            x: CGFloat(column) * columnWidth + columnWidth / 2,
            y: assignmentsListY + listHeight / 2
        )
    }
}

#Preview {
    let store = PlannerTaskStore()
    let dates = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    WeeklyOverviewView(
        weekDates: dates,
        tasksProvider: { _ in store.allTasks() },
        assignmentsProvider: { _ in [] },
        onSelectDay: { _ in },
        selectedDate: Date(),
        onSelectTask: { _ in }
    )
}
