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
    let onSelectDay: (Date) -> Void
    let onSelectTask: ((PlannerTask) -> Void)?
    let selectedDate: Date
    
    init(weekDates: [Date], tasksProvider: @escaping (Date) -> [PlannerTask], onSelectDay: @escaping (Date) -> Void, selectedDate: Date, onSelectTask: ((PlannerTask) -> Void)? = nil) {
        self.weekDates = weekDates
        self.tasksProvider = tasksProvider
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

    private let hours: [Int] = Array(6...23)
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
                        
                        // Grid and tasks (offset to account for headers)
                        ZStack(alignment: .topLeading) {
                            drawGrid()
                            drawTasks()
                        }
                        .frame(
                            width: columnWidth * CGFloat(weekDates.count),
                            height: rowHeight * CGFloat(hours.count)
                        )
                        .offset(x: columnWidth, y: rowHeight * 2)
                    }
                    .frame(
                        width: columnWidth + (columnWidth * CGFloat(weekDates.count)),
                        height: rowHeight + (rowHeight * CGFloat(hours.count)),
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
                TasksForDay(tasks: tasks, column: column, columnWidth: columnWidth, rowHeight: rowHeight, hours: hours, onSelectTask: onSelectTask)
            }
        }
    }
}

private struct TasksForDay: View {
    let tasks: [PlannerTask]
    let column: Int
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let hours: [Int]
    let onSelectTask: ((PlannerTask) -> Void)?

    private var dayStart: Date {
        Calendar.current.startOfDay(for: tasks.first?.startDate ?? Date())
    }
    private var visibleStart: Date {
        Calendar.current.date(bySettingHour: hours.first ?? 6, minute: 0, second: 0, of: dayStart) ?? dayStart
    }
    private var visibleEnd: Date {
        Calendar.current.date(bySettingHour: (hours.last ?? 22) + 1, minute: 0, second: 0, of: dayStart) ?? dayStart
    }

    var body: some View {
        ForEach(tasks) { task in
            let rect = rectForTask(task)
            let isAssignment = task.id.hasPrefix("assignment-")
            Button {
                onSelectTask?(task)
            } label: {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isAssignment ? task.color.opacity(0.9) : task.color.opacity(0.8))
                    .frame(width: columnWidth - 12, height: max(rect.height, 24), alignment: .leading)
                    .overlay(
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                if isAssignment {
                                    Image(systemName: "doc.text.fill")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                Text(task.title)
                                    .font(isAssignment ? .caption2.bold() : .caption2.bold())
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.horizontal, 6)
                            .padding(.top, 6)
                            Spacer(minLength: 4)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isAssignment ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .position(x: rect.midX, y: rect.midY)
        }
    }

    private func rectForTask(_ task: PlannerTask) -> CGRect {
        let totalInterval = max(visibleEnd.timeIntervalSince(visibleStart), 60 * 60)
        let clampedStart = max(task.startDate, visibleStart)
        let clampedEnd = min(task.startDate.addingTimeInterval(TimeInterval(task.durationMinutes * 60)), visibleEnd)
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
}

#Preview {
    let store = PlannerTaskStore()
    let dates = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    WeeklyOverviewView(
        weekDates: dates,
        tasksProvider: { _ in store.allTasks() },
        onSelectDay: { _ in },
        selectedDate: Date(),
        onSelectTask: { _ in }
    )
}
