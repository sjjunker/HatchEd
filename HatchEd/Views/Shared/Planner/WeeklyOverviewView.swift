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

    private let hours: [Int] = Array(0...23)
    private let rowHeight: CGFloat = 45

    var body: some View {
        GeometryReader { outerGeometry in
            let isLandscape = outerGeometry.size.width > outerGeometry.size.height
            let dayHeaderHeight: CGFloat = isLandscape ? 28 : rowHeight

            ZStack(alignment: .topLeading) {
                // ScrollView containing scrollable content
                GeometryReader { geometry in
                    let dayColumnWidth = max(44, geometry.size.width / CGFloat(max(weekDates.count, 1)))
                    ScrollView([.vertical], showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            // Grid and tasks
                            ZStack(alignment: .topLeading) {
                                drawGrid(columnWidth: dayColumnWidth)
                                drawTasks(columnWidth: dayColumnWidth, showTitleCards: isLandscape)
                            }
                            .frame(
                                width: gridWidth(columnWidth: dayColumnWidth),
                                height: rowHeight * CGFloat(hours.count)
                            )
                            .offset(y: dayHeaderHeight)
                        }
                        .frame(
                            width: gridWidth(columnWidth: dayColumnWidth),
                            height: dayHeaderHeight + (rowHeight * CGFloat(hours.count)),
                            alignment: .topLeading
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color.hatchEdBackground)
                }
                
                // Sticky day headers overlay (stays visible when scrolling vertically)
                GeometryReader { headerGeometry in
                    HStack(spacing: 0) {
                        drawDayHeaders(
                            columnWidth: max(44, headerGeometry.size.width / CGFloat(max(weekDates.count, 1))),
                            dayHeaderHeight: dayHeaderHeight
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: dayHeaderHeight)
                    .background(Color.hatchEdBackground)
                    .zIndex(2)
                }
            }
            .background(Color.hatchEdBackground)
        }
    }

    private func gridWidth(columnWidth: CGFloat) -> CGFloat {
        columnWidth * CGFloat(weekDates.count)
    }

    private func drawGrid(columnWidth: CGFloat) -> some View {
        let width = gridWidth(columnWidth: columnWidth)
        let height = rowHeight * CGFloat(hours.count)
        let labelX: CGFloat = 28
        let lineGap: CGFloat = 40
        
        return ZStack(alignment: .topLeading) {
            Path { path in
                for row in 0...hours.count {
                    let y = CGFloat(row) * rowHeight
                    let leftEndX = max(0, labelX - (lineGap / 2))
                    let rightStartX = min(width, labelX + (lineGap / 2))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: leftEndX, y: y))
                    path.move(to: CGPoint(x: rightStartX, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }

            }
            .stroke(Color.hatchEdSecondaryBackground.opacity(0.8), lineWidth: 1.25)

            Path { path in
                for column in 0...weekDates.count {
                    let x = CGFloat(column) * columnWidth
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
            }
            .stroke(Color.hatchEdSecondaryBackground, lineWidth: 1)

            ForEach(Array(hours.enumerated()), id: \.offset) { index, hour in
                Text(hourLabel(for: hour))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.hatchEdSecondaryText.opacity(0.65))
                    .padding(.horizontal, 4)
                    .background(Color.hatchEdBackground)
                    .position(x: labelX, y: CGFloat(index) * rowHeight)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func hourLabel(for hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return hourFormatter
            .string(from: date)
            .replacingOccurrences(of: ".", with: "")
            .uppercased()
    }

    private func drawDayHeaders(columnWidth: CGFloat, dayHeaderHeight: CGFloat) -> some View {
        let isCompact = dayHeaderHeight < rowHeight
        return HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                Button {
                    onSelectDay(date)
                } label: {
                    Group {
                        if isCompact {
                            Text("\(weekdayFormatter.string(from: date)) - \(date.formatted(.dateTime.day()))")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(isSelected ? .hatchEdWhite : .hatchEdText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        } else {
                            VStack(spacing: 6) {
                                Text(weekdayFormatter.string(from: date).uppercased())
                                    .font(.caption)
                                    .foregroundColor(isSelected ? .hatchEdWhite : .hatchEdSecondaryText)
                                Text(date.formatted(.dateTime.day()))
                                    .font(.headline)
                                    .foregroundColor(isSelected ? .hatchEdWhite : .hatchEdText)
                            }
                        }
                    }
                    .padding(.vertical, isCompact ? 2 : 0)
                    .frame(width: columnWidth, height: dayHeaderHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.hatchEdAccent : Color.hatchEdSecondaryBackground)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func drawTasks(columnWidth: CGFloat, showTitleCards: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(weekDates.indices, id: \.self) { column in
                let date = weekDates[column]
                let tasks = tasksProvider(date)
                let regularTasks = tasks.filter { !$0.id.hasPrefix("assignment-") }
                let inScopeAssignments = assignmentsProvider(date)
                TasksForDay(
                    date: date,
                    tasks: regularTasks + inScopeAssignments,
                    column: column,
                    columnWidth: columnWidth,
                    rowHeight: rowHeight,
                    hours: hours,
                    showTitleCards: showTitleCards,
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
}

private struct TasksForDay: View {
    let date: Date
    let tasks: [PlannerTask]
    let column: Int
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let hours: [Int]
    let showTitleCards: Bool
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
        Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 60 * 60)
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
                        Group {
                            if showTitleCards {
                                titleCardView(for: slot, isCluster: isCluster)
                                    .frame(width: rect.width, height: max(rect.height, 28), alignment: .leading)
                            } else {
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
                            }
                        }
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
                .font(.system(size: 18, weight: .semibold))
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
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                        dueAwareAssignmentSymbol(isDue: slot.hasDueItem, baseColor: .white.opacity(0.95))
                            .scaleEffect(0.65)
                        if isCluster {
                            Text("\(slot.tasks.count)")
                                .font(.system(size: 8, weight: .bold))
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
            return CGSize(width: 21, height: 21)
        case .assignment:
            return CGSize(width: 21, height: 21)
        case .mixed:
            return CGSize(width: 30, height: 18)
        }
    }

    private func titleCardView(for slot: TaskSlot, isCluster: Bool) -> some View {
        HStack(spacing: 6) {
            switch slot.markerKind {
            case .task:
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.95))
            case .assignment, .mixed:
                dueAwareAssignmentSymbol(isDue: slot.hasDueItem, baseColor: .white.opacity(0.95))
                    .scaleEffect(0.8)
            }

            Text(isCluster ? "\(slot.tasks.count) items" : slot.primary.title)
                .font(.caption2.bold())
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(slot.primary.color.opacity(0.88))
        )
    }

    private func dueAwareAssignmentSymbol(isDue: Bool, baseColor: Color) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "doc.text")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(baseColor)
            if isDue {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.red)
                    .offset(x: 3, y: -3)
            }
        }
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
