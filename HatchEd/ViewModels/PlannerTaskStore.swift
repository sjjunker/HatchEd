//
//  PlannerTaskStore.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import Foundation

@MainActor
final class PlannerTaskStore: ObservableObject {
    @Published private(set) var tasks: [PlannerTask] = []

    private let cache = OfflineCache.shared
    private let cacheFile = "plannerTasks.json"
    private let calendar = Calendar.current

    init() {
        load()
    }

    func tasks(for date: Date) -> [PlannerTask] {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        return tasks.filter { $0.startDate >= startOfDay && $0.startDate < endOfDay }
            .sorted { $0.startDate < $1.startDate }
    }

    func add(_ task: PlannerTask) {
        tasks.append(task)
        tasks.sort { $0.startDate < $1.startDate }
        save()
    }

    func remove(_ task: PlannerTask) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func allTasks() -> [PlannerTask] {
        tasks
    }

    private func load() {
        if let stored: [PlannerTask] = cache.load([PlannerTask].self, from: cacheFile) {
            tasks = stored
        }
    }

    private func save() {
        cache.save(tasks, as: cacheFile)
    }
}
