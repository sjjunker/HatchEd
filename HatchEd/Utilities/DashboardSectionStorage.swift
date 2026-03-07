//
//  DashboardSectionStorage.swift
//  HatchEd
//
//  Persists dashboard section order and visibility.
//

import Foundation
import SwiftUI

/// Observable state for dashboard sections; use with @StateObject.
final class DashboardSectionState: ObservableObject {
    @Published private(set) var sectionOrder: [String]
    @Published private(set) var hiddenSectionIds: Set<String>
    private var storage: DashboardSectionStorage
    
    var visibleSectionIds: [String] {
        sectionOrder.filter { !hiddenSectionIds.contains($0) }
    }
    
    var hiddenSectionIdsArray: [String] {
        Array(hiddenSectionIds).sorted()
    }
    
    init(storage: DashboardSectionStorage) {
        self.storage = storage
        self.sectionOrder = storage.sectionOrder
        self.hiddenSectionIds = storage.hiddenSectionIds
    }
    
    func refreshFromStorage() {
        sectionOrder = storage.sectionOrder
        hiddenSectionIds = storage.hiddenSectionIds
    }
    
    func hideSection(_ id: String) {
        storage.hideSection(id)
        refreshFromStorage()
    }
    
    func unhideSection(_ id: String) {
        storage.unhideSection(id)
        refreshFromStorage()
    }
    
    func move(from source: IndexSet, to destination: Int) {
        var visible = visibleSectionIds
        visible.move(fromOffsets: source, toOffset: destination)
        let hidden = sectionOrder.filter { hiddenSectionIds.contains($0) }
        storage.sectionOrder = visible + hidden
        refreshFromStorage()
    }
}

/// Manages persisted order and visibility of dashboard sections.
struct DashboardSectionStorage {
    private let orderKey: String
    private let hiddenKey: String
    private let defaultOrder: [String]
    
    init(orderKey: String, hiddenKey: String, defaultOrder: [String]) {
        self.orderKey = orderKey
        self.hiddenKey = hiddenKey
        self.defaultOrder = defaultOrder
    }
    
    var sectionOrder: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: orderKey),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                return defaultOrder
            }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: orderKey)
        }
    }
    
    var hiddenSectionIds: Set<String> {
        get {
            guard let data = UserDefaults.standard.data(forKey: hiddenKey),
                  let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: hiddenKey)
        }
    }
    
    var visibleSectionIds: [String] {
        sectionOrder.filter { !hiddenSectionIds.contains($0) }
    }
    
    mutating func hideSection(_ id: String) {
        var hidden = hiddenSectionIds
        hidden.insert(id)
        hiddenSectionIds = hidden
    }
    
    mutating func unhideSection(_ id: String) {
        var hidden = hiddenSectionIds
        hidden.remove(id)
        hiddenSectionIds = hidden
        var order = sectionOrder
        if !order.contains(id) {
            order.append(id)
            sectionOrder = order
        }
    }
}
