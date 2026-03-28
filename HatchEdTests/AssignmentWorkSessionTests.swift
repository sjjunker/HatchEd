//
//  AssignmentWorkSessionTests.swift
//  HatchEdTests
//
//  Work-session scheduling and decoding (strict mode, catch-up, clamps).
//

import Foundation
import Testing
@testable import HatchEd

struct AssignmentWorkSessionTests {

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func mayIncrementWhenNoWorkDatesReturnsFalse() {
        let a = Assignment(title: "T", studentId: "s1", workDates: [], completed: false, workSessionsCompleted: 0, strictWorkSessionProgress: false)
        #expect(a.mayIncrementWorkSession(calendar: utcCalendar) == false)
    }

    @Test func mayIncrementWhenAllSessionsLoggedReturnsFalse() {
        let d1 = date(2026, 3, 1, calendar: utcCalendar)
        let d2 = date(2026, 3, 2, calendar: utcCalendar)
        let a = Assignment(
            title: "T",
            studentId: "s1",
            workDates: [d1, d2],
            completed: false,
            workSessionsCompleted: 2,
            strictWorkSessionProgress: false
        )
        #expect(a.mayIncrementWorkSession(calendar: utcCalendar) == false)
    }

    @Test func mayIncrementWhenStrictOffAllowsUntilCap() {
        let d1 = date(2100, 1, 1, calendar: utcCalendar)
        let a = Assignment(
            title: "T",
            studentId: "s1",
            workDates: [d1],
            completed: false,
            workSessionsCompleted: 0,
            strictWorkSessionProgress: false
        )
        #expect(a.mayIncrementWorkSession(calendar: utcCalendar) == true)
    }

    @Test func mayIncrementWhenStrictOnAndFirstSessionIsFutureReturnsFalse() {
        let future = date(2100, 6, 1, calendar: utcCalendar)
        let a = Assignment(
            title: "T",
            studentId: "s1",
            workDates: [future],
            completed: false,
            workSessionsCompleted: 0,
            strictWorkSessionProgress: true
        )
        #expect(a.mayIncrementWorkSession(calendar: utcCalendar) == false)
    }

    @Test func mayIncrementWhenStrictOnAndFirstSessionIsPastReturnsTrue() {
        let past = date(2000, 1, 1, calendar: utcCalendar)
        let a = Assignment(
            title: "T",
            studentId: "s1",
            workDates: [past],
            completed: false,
            workSessionsCompleted: 0,
            strictWorkSessionProgress: true
        )
        #expect(a.mayIncrementWorkSession(calendar: utcCalendar) == true)
    }

    @Test func mayIncrementStrictSecondSessionUnlocksAfterFirstDay() {
        let day1 = date(2000, 1, 1, calendar: utcCalendar)
        let day2 = date(2000, 1, 3, calendar: utcCalendar)
        let a = Assignment(
            title: "T",
            studentId: "s1",
            workDates: [day2, day1],
            completed: false,
            workSessionsCompleted: 1,
            strictWorkSessionProgress: true
        )
        #expect(a.mayIncrementWorkSession(calendar: utcCalendar) == true)
    }

    @Test func workSessionTotalMatchesWorkDatesCount() {
        let a = Assignment(title: "T", studentId: "s1", workDates: [Date(), Date(), Date()])
        #expect(a.workSessionTotal == 3)
    }

    @Test func initClampsNegativeWorkSessionsCompleted() {
        let a = Assignment(title: "T", studentId: "s1", completed: false, workSessionsCompleted: -5)
        #expect(a.workSessionsCompleted == 0)
    }

    @Test func decodeClampsNegativeWorkSessionsCompleted() throws {
        let json = """
        {"id": "x", "title": "T", "studentId": "s1", "workDates": [], "workDurationsMinutes": [], "questions": [], "completed": false, "workSessionsCompleted": -3}
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let a = try decoder.decode(Assignment.self, from: data)
        #expect(a.workSessionsCompleted == 0)
    }

    @Test func encodeDecodeRoundTripPreservesWorkSessionFields() throws {
        let d1 = date(2026, 4, 1, calendar: utcCalendar)
        let original = Assignment(
            id: "id-1",
            title: "Lab",
            studentId: "s1",
            workDates: [d1],
            completed: false,
            workSessionsCompleted: 1,
            strictWorkSessionProgress: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Assignment.self, from: data)
        #expect(decoded.workSessionsCompleted == 1)
        #expect(decoded.strictWorkSessionProgress == true)
        #expect(decoded.workSessionTotal == 1)
    }

    @Test func decodeStrictWorkSessionDefaultsFalseWhenKeyMissing() throws {
        let json = """
        {"id": "a", "title": "T", "studentId": "s1", "workDates": [], "workDurationsMinutes": [], "questions": [], "completed": false, "workSessionsCompleted": 0}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let a = try decoder.decode(Assignment.self, from: Data(json.utf8))
        #expect(a.strictWorkSessionProgress == false)
    }
}
