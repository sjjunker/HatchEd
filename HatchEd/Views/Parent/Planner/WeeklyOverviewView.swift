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

    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Week at a Glance")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 16) {
                    ForEach(weekDates, id: \.self) { date in
                        let tasks = tasksProvider(date)
                        WeeklyOverviewColumn(
                            date: date,
                            tasks: tasks,
                            weekdayFormatter: weekdayFormatter,
                            dayFormatter: dayFormatter,
                            onSelect: onSelectDay
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
}

private struct WeeklyOverviewColumn: View {
    let date: Date
    let tasks: [PlannerTask]
    let weekdayFormatter: DateFormatter
    let dayFormatter: DateFormatter
    let onSelect: (Date) -> Void

    var body: some View {
        Button {
            onSelect(date)
        } label: {
            VStack(spacing: 8) {
                Text(weekdayFormatter.string(from: date).uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(dayFormatter.string(from: date))
                    .font(.headline)

                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(width: 52, height: 220)

                    if tasks.isEmpty {
                        Text("+")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .opacity(0.25)
                    } else {
                        WeeklyTaskStack(tasks: tasks)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WeeklyTaskStack: View {
    let tasks: [PlannerTask]

    var body: some View {
        VStack(spacing: 0) {
            let totalMinutes = max(tasks.map { $0.durationMinutes }.reduce(0, +), 60)
            ForEach(tasks) { task in
                let fraction = CGFloat(task.durationMinutes) / CGFloat(totalMinutes)
                PlannerTaskBarView(task: task, heightFraction: fraction)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
        .frame(width: 52, height: 220)
    }
}

private struct PlannerTaskBarView: View {
    let task: PlannerTask
    let heightFraction: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(task.color)
            .frame(height: max(36, heightFraction * 200))
            .overlay(
                VStack(alignment: .leading) {
                    Text(task.title)
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(6)
                    Spacer(minLength: 0)
                }
            )
            .padding(.horizontal, 2)
            .padding(.top, 4)
    }
}

#Preview {
    let store = PlannerTaskStore()
    let dates = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    WeeklyOverviewView(weekDates: dates, tasksProvider: { _ in store.allTasks() }, onSelectDay: { _ in })
}
