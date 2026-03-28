//
//  DashboardSectionStorageTests.swift
//  HatchEdTests
//
//  Dashboard section order merge (new sections after app updates).
//

import Foundation
import Testing
@testable import HatchEd

struct DashboardSectionStorageTests {

    @Test func mergeSavedOrderAppendsMissingIds() {
        let saved = ["welcome", "quote"]
        let defaults = ["welcome", "notifications", "quote", "incompleteAssignments"]
        let merged = DashboardSectionStorage.mergeSavedOrder(saved, defaultOrder: defaults)
        #expect(merged == ["welcome", "quote", "notifications", "incompleteAssignments"])
    }

    @Test func mergeSavedOrderPreservesOrderWhenComplete() {
        let full = ["a", "b", "c"]
        let merged = DashboardSectionStorage.mergeSavedOrder(full, defaultOrder: ["a", "b", "c"])
        #expect(merged == ["a", "b", "c"])
    }

    @Test func mergeSavedOrderEmptySavedGetsAllDefaults() {
        let merged = DashboardSectionStorage.mergeSavedOrder([], defaultOrder: ["x", "y"])
        #expect(merged == ["x", "y"])
    }

    @Test func mergeSavedOrderDoesNotDuplicate() {
        let saved = ["welcome", "dailyAssignments"]
        let defaults = ["welcome", "dailyAssignments", "quote"]
        let merged = DashboardSectionStorage.mergeSavedOrder(saved, defaultOrder: defaults)
        #expect(merged == ["welcome", "dailyAssignments", "quote"])
    }
}
