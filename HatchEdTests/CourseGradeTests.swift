//
//  CourseGradeTests.swift
//  HatchEdTests
//
//  Course.calculatedGrade edge cases.
//

import Foundation
import Testing
@testable import HatchEd

struct CourseGradeTests {

    private let student = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "S", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
    private let other = User(id: "s2", appleId: nil, googleId: nil, username: nil, name: "T", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)

    @Test func calculatedGradeNilWhenMultipleStudentsAndNoStudentId() {
        let a = Assignment(title: "Q", studentId: "s1", pointsPossible: 100, pointsAwarded: 80, completed: true)
        let course = Course(name: "Math", assignments: [a], students: [student, other])
        #expect(course.calculatedGrade(for: nil) == nil)
    }

    @Test func calculatedGradeUsesSingleStudentWhenOmitted() {
        let a = Assignment(title: "Q", studentId: "s1", pointsPossible: 100, pointsAwarded: 90, completed: true)
        let course = Course(name: "Math", assignments: [a], students: [student])
        #expect(course.calculatedGrade(for: nil) == 90)
    }

    @Test func calculatedGradeIgnoresZeroPointsPossible() {
        let bad = Assignment(title: "X", studentId: "s1", pointsPossible: 0, pointsAwarded: 50, completed: true)
        let good = Assignment(title: "Y", studentId: "s1", pointsPossible: 100, pointsAwarded: 80, completed: true)
        let course = Course(name: "Mix", assignments: [bad, good], students: [student])
        #expect(course.calculatedGrade(for: "s1") == 80)
    }

    @Test func calculatedGradeFiltersOtherStudentAssignments() {
        let mine = Assignment(title: "A", studentId: "s1", pointsPossible: 100, pointsAwarded: 100, completed: true)
        let theirs = Assignment(title: "B", studentId: "s2", pointsPossible: 100, pointsAwarded: 0, completed: true)
        let course = Course(name: "C", assignments: [mine, theirs], students: [student, other])
        #expect(course.calculatedGrade(for: "s1") == 100)
    }
}
