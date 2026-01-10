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
    @Published private(set) var isLoading: Bool = false

    private let cache = OfflineCache.shared
    private let cacheFile = "plannerTasks.json"
    private let calendar = Calendar.current
    private let api = APIClient.shared

    init() {
        loadFromCache()
        Task {
            await loadFromServer()
        }
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
        // Task is already created on server, just add to local store
        tasks.append(task)
        tasks.sort { $0.startDate < $1.startDate }
        saveToCache()
    }
    
    func remove(_ task: PlannerTask) async {
        // Delete from server first
        do {
            try await api.deletePlannerTask(id: task.id)
            tasks.removeAll { $0.id == task.id }
            saveToCache()
        } catch {
            print("Failed to delete task from server: \(error)")
            // Still remove locally if server deletion fails
            tasks.removeAll { $0.id == task.id }
            saveToCache()
        }
    }

    func allTasks() -> [PlannerTask] {
        tasks
    }
    
    func refresh() async {
        await loadFromServer()
    }

    private func loadFromCache() {
        if let stored: [PlannerTask] = cache.load([PlannerTask].self, from: cacheFile) {
            tasks = stored
        }
    }
    
    private func loadFromServer() async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            let serverTasks = try await api.fetchPlannerTasks()
            tasks = serverTasks
            tasks.sort { $0.startDate < $1.startDate }
            saveToCache()
        } catch {
            print("Failed to load tasks from server: \(error)")
            // Keep cached tasks if server load fails
        }
        
        isLoading = false
    }

    private func saveToCache() {
        cache.save(tasks, as: cacheFile)
    }
}
