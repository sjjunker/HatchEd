//
//  ViewModelTests.swift
//  HatchEdTests
//
//  Unit tests for ViewModel logic using Swift Testing.
//

import Testing
import Foundation
@testable import HatchEd

@MainActor
struct ViewModelTests {

    // MARK: - GradeHelper.percentage (pure helper; no actor)

    @Test func percentageReturnsNilWhenPointsPossibleZero() {
        #expect(GradeHelper.percentage(pointsAwarded: 80, pointsPossible: 0) == nil)
    }

    @Test func percentageReturnsNilWhenPointsPossibleNegative() {
        #expect(GradeHelper.percentage(pointsAwarded: 50, pointsPossible: -10) == nil)
    }

    @Test func percentageCalculatesCorrectly() {
        #expect(GradeHelper.percentage(pointsAwarded: 85, pointsPossible: 100) == 85.0)
        #expect(GradeHelper.percentage(pointsAwarded: 1, pointsPossible: 3) == (1.0 / 3.0) * 100)
    }

    @Test func percentageFullMarks() {
        #expect(GradeHelper.percentage(pointsAwarded: 100, pointsPossible: 100) == 100.0)
    }

    // MARK: - AddPortfolioViewModel (suite is @MainActor)

    @Test func addPortfolioViewModelIsValidFalseWhenNoStudent() {
        let vm = AddPortfolioViewModel()
        #expect(vm.selectedStudent == nil)
        #expect(vm.isValid == false)
    }

    @Test func addPortfolioViewModelIsValidTrueWhenStudentSet() {
        let vm = AddPortfolioViewModel()
        let user = User(id: "u1", appleId: nil, googleId: nil, username: nil, name: "Test", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        vm.selectedStudent = user
        #expect(vm.isValid == true)
    }

    @Test func addPortfolioViewModelToggleWorkFile() {
        let vm = AddPortfolioViewModel()
        let file = StudentWorkFile(fileName: "doc.pdf", fileUrl: "url", fileType: "application/pdf", fileSize: 100, studentId: "s1")
        #expect(vm.selectedWorkFiles.isEmpty)
        vm.toggleWorkFile(file)
        #expect(vm.selectedWorkFiles.contains(file))
        vm.toggleWorkFile(file)
        #expect(vm.selectedWorkFiles.isEmpty)
    }

    // MARK: - AttendanceSubmissionState

    @Test func attendanceSubmissionStateEquatable() {
        let idle = AttendanceSubmissionState.idle
        let success = AttendanceSubmissionState.success(message: "Done")
        let failure = AttendanceSubmissionState.failure(message: "Error")
        #expect(idle == .idle)
        #expect(success == .success(message: "Done"))
        #expect(failure == .failure(message: "Error"))
        #expect(AttendanceSubmissionState.success(message: "Done") == AttendanceSubmissionState.success(message: "Done"))
    }

    // MARK: - PortfolioListViewModel

    @Test func portfolioListViewModelInitialState() {
        let vm = PortfolioListViewModel()
        #expect(vm.portfolios.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - StudentDetailViewModel

    @Test func studentDetailViewModelAttendanceFromRecords() throws {
        let student = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "Student", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json1 = """
        {"id": "r1", "familyId": "f1", "studentUserId": "s1", "recordedByUserId": "p1", "date": "2025-01-15T12:00:00Z", "status": "present", "isPresent": true}
        """
        let json2 = """
        {"id": "r2", "familyId": "f1", "studentUserId": "s1", "recordedByUserId": "p1", "date": "2025-01-14T12:00:00Z", "status": "absent", "isPresent": false}
        """
        let r1 = try decoder.decode(AttendanceRecordDTO.self, from: Data(json1.utf8))
        let r2 = try decoder.decode(AttendanceRecordDTO.self, from: Data(json2.utf8))
        let vm = StudentDetailViewModel(student: student, courses: [], assignments: [], attendanceRecords: [r1, r2])
        #expect(vm.attendance.classesAttended == 1)
        #expect(vm.attendance.classesMissed == 1)
        #expect(vm.attendance.totalClasses == 2)
        #expect(vm.attendance.average == 0.5)
        #expect(vm.attendance.streakDays == 1)
    }

    @Test func studentDetailViewModelSnapshotReflectsState() {
        let student = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "Alex", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        let vm = StudentDetailViewModel(student: student, courses: [], assignments: [], attendanceRecords: [])
        let snapshot = vm.makeSnapshot()
        #expect(snapshot.studentName == "Alex")
        #expect(snapshot.attendanceAverage == 0)
        #expect(snapshot.classesAttendedText == "0")
        #expect(snapshot.classesMissedText == "0")
        #expect(snapshot.attendanceStreakText == "No streak")
    }

    @Test func studentDetailViewModelAttendancePercentageString() throws {
        let student = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "S", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = """
        {"id": "r1", "familyId": "f1", "studentUserId": "s1", "recordedByUserId": "p1", "date": "2025-01-15T12:00:00Z", "status": "present", "isPresent": true}
        """
        let r1 = try decoder.decode(AttendanceRecordDTO.self, from: Data(json.utf8))
        let vm = StudentDetailViewModel(student: student, courses: [], assignments: [], attendanceRecords: [r1])
        #expect(vm.attendancePercentageString == "100%" || vm.attendancePercentageString.contains("100"))
    }

    // MARK: - AddPortfolioViewModel

    @Test func addPortfolioViewModelClearError() {
        let vm = AddPortfolioViewModel()
        vm.clearError()
        #expect(vm.errorMessage == nil)
    }

    @Test func addPortfolioViewModelDesignPatternDefaultsToGeneral() {
        let vm = AddPortfolioViewModel()
        #expect(vm.selectedDesignPattern == .general)
    }

    @Test func addPortfolioViewModelSectionTextFieldsInitialEmpty() {
        let vm = AddPortfolioViewModel()
        #expect(vm.studentRemarks == "")
        #expect(vm.aboutMe == "")
        #expect(vm.achievementsAndAwards == "")
    }
}
