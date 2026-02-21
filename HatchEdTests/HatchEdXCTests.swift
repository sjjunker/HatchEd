//
//  HatchEdXCTests.swift
//  HatchEdTests
//
//  Unit tests using XCTest (Apple’s classic testing framework).
//  Run with Product → Test (⌘U) or the Test navigator.
//

import XCTest
@testable import HatchEd

final class HatchEdXCTests: XCTestCase {

    // MARK: - Portfolio

    func testPortfolioDesignPatternRawValues() {
        XCTAssertEqual(PortfolioDesignPattern.general.rawValue, "General")
        XCTAssertEqual(PortfolioDesignPattern.artistic.rawValue, "Artistic")
    }

    func testPortfolioDecodesFromJSON() throws {
        let json = """
        {
            "id": "p1",
            "studentId": "s1",
            "studentName": "Alex",
            "designPattern": "Academic",
            "studentWorkFileIds": [],
            "compiledContent": "Content here",
            "snippet": "Preview",
            "generatedImages": []
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let portfolio = try decoder.decode(Portfolio.self, from: data)
        XCTAssertEqual(portfolio.id, "p1")
        XCTAssertEqual(portfolio.studentName, "Alex")
        XCTAssertEqual(portfolio.designPattern, .academic)
        XCTAssertEqual(portfolio.compiledContent, "Content here")
        XCTAssertEqual(portfolio.snippet, "Preview")
    }

    func testPortfolioDecodesWithMissingOptionals() throws {
        let json = """
        {
            "id": "p2",
            "studentId": "s2",
            "studentName": "Sam",
            "designPattern": "General",
            "compiledContent": "",
            "snippet": "",
            "generatedImages": []
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let portfolio = try decoder.decode(Portfolio.self, from: data)
        XCTAssertEqual(portfolio.studentWorkFileIds, [])
        XCTAssertNil(portfolio.reportCardSnapshot)
        XCTAssertNil(portfolio.sectionData)
    }

    /// Custom Portfolio decoding: invalid generatedImages (e.g. object) yields empty array.
    func testPortfolioDecodesWhenGeneratedImagesInvalid() throws {
        let json = """
        {"id":"p4","studentId":"s4","studentName":"Pat","designPattern":"Creative","compiledContent":"","snippet":"","generatedImages":{}}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let portfolio = try decoder.decode(Portfolio.self, from: Data(json.utf8))
        XCTAssertTrue(portfolio.generatedImages.isEmpty)
        XCTAssertEqual(portfolio.studentName, "Pat")
    }

    // MARK: - User

    func testUserIsParent() {
        let user = User(id: "1", appleId: nil, googleId: nil, username: nil, name: "P", email: nil, role: "parent", familyId: "f1", createdAt: nil, updatedAt: nil)
        XCTAssertTrue(user.isParent)
        XCTAssertFalse(user.isStudent)
    }

    func testUserRequiresFamilyWhenStudentNoFamilyId() {
        let user = User(id: "1", appleId: nil, googleId: nil, username: nil, name: nil, email: nil, role: "student", familyId: nil, createdAt: nil, updatedAt: nil)
        XCTAssertTrue(user.requiresFamily)
    }

    // MARK: - GradeHelper percentage

    func testPercentageHelper() {
        XCTAssertNil(GradeHelper.percentage(pointsAwarded: 10, pointsPossible: 0))
        XCTAssertEqual(GradeHelper.percentage(pointsAwarded: 75, pointsPossible: 100), 75.0)
    }

    // MARK: - Assignment

    func testAssignmentIsCompleted() {
        let a = Assignment(title: "T", studentId: "s1", pointsPossible: 100, pointsAwarded: 90, completed: false)
        XCTAssertTrue(a.isCompleted)
    }

    func testAssignmentNotCompletedWhenNoPoints() {
        let a = Assignment(title: "T", studentId: "s1", pointsPossible: 100, pointsAwarded: nil, completed: false)
        XCTAssertFalse(a.isCompleted)
    }

    // MARK: - Course

    func testCourseInit() {
        let user = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "S", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        let assignment = Assignment(title: "Quiz", studentId: "s1", pointsPossible: 20, pointsAwarded: 17, completed: true)
        let course = Course(name: "Math", assignments: [assignment], students: [user])
        XCTAssertEqual(course.name, "Math")
        XCTAssertEqual(course.calculatedGrade(for: "s1"), 85)
    }

    // MARK: - Family

    func testFamilyDecode() throws {
        let json = """
        {"id": "f1", "name": "Smith", "joinCode": "XYZ", "members": ["u1"]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let family = try decoder.decode(Family.self, from: Data(json.utf8))
        XCTAssertEqual(family.id, "f1")
        XCTAssertEqual(family.name, "Smith")
        XCTAssertEqual(family.members.count, 1)
    }

    // MARK: - AppTheme

    func testAppThemeConstants() {
        XCTAssertEqual(AppTheme.cornerRadius, 12)
        XCTAssertEqual(AppTheme.cardPadding, 16)
        XCTAssertEqual(AppTheme.sectionSpacing, 24)
    }

    // MARK: - PlannerTask

    func testPlannerTaskColorOptions() {
        XCTAssertEqual(PlannerTask.colorOptions.count, 7)
    }
}
