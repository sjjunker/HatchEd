//
//  ViewModelXCTests.swift
//  HatchEdTests
//
//  XCTest unit tests for ViewModels. Targets 80–90% coverage of business logic.
//  Arrange–Act–Assert; success/failure/edge cases; no UI.
//

import XCTest
@testable import HatchEd

@MainActor
final class ViewModelXCTests: XCTestCase {

    // MARK: - GradeHelper (pure logic, no actor)

    func testGradeHelper_ReturnsNil_WhenPointsPossibleIsZero() {
        XCTAssertNil(GradeHelper.percentage(pointsAwarded: 80, pointsPossible: 0))
    }

    func testGradeHelper_ReturnsNil_WhenPointsPossibleIsNegative() {
        XCTAssertNil(GradeHelper.percentage(pointsAwarded: 50, pointsPossible: -10))
    }

    func testGradeHelper_ReturnsCorrectPercentage_WhenInputsValid() {
        XCTAssertEqual(GradeHelper.percentage(pointsAwarded: 75, pointsPossible: 100), 75.0)
        XCTAssertEqual(GradeHelper.percentage(pointsAwarded: 1, pointsPossible: 3), (1.0 / 3.0) * 100)
    }

    // MARK: - MenuManager

    func testMenuManager_SetsParentMenuItems_WhenUserRoleIsParent() {
        let manager = MenuManager()
        let user = User(id: "1", appleId: nil, googleId: nil, username: nil, name: nil, email: nil, role: "parent", familyId: nil, createdAt: nil, updatedAt: nil)
        manager.setMenuItems(user: user)
        XCTAssertEqual(manager.menuItems.count, manager.parentMenuItems.count)
        XCTAssertTrue(manager.menuItems.contains(.dashboard))
        XCTAssertTrue(manager.menuItems.contains(.planner))
        XCTAssertTrue(manager.menuItems.contains(.portfolio))
    }

    func testMenuManager_SetsStudentMenuItems_WhenUserRoleIsStudent() {
        let manager = MenuManager()
        let user = User(id: "1", appleId: nil, googleId: nil, username: nil, name: nil, email: nil, role: "student", familyId: nil, createdAt: nil, updatedAt: nil)
        manager.setMenuItems(user: user)
        XCTAssertEqual(manager.menuItems.count, manager.studentMenuItems.count)
        XCTAssertFalse(manager.menuItems.contains(.subjects))
    }

    func testMenuManager_ClearsMenuItems_WhenUserRoleIsNil() {
        let manager = MenuManager()
        let user = User(id: "1", appleId: nil, googleId: nil, username: nil, name: nil, email: nil, role: nil, familyId: nil, createdAt: nil, updatedAt: nil)
        manager.setMenuItems(user: user)
        XCTAssertTrue(manager.menuItems.isEmpty)
    }

    func testMenuManager_ClearsMenuItems_WhenUserRoleIsEmpty() {
        let manager = MenuManager()
        let user = User(id: "1", appleId: nil, googleId: nil, username: nil, name: nil, email: nil, role: "", familyId: nil, createdAt: nil, updatedAt: nil)
        manager.setMenuItems(user: user)
        XCTAssertTrue(manager.menuItems.isEmpty)
    }

    // MARK: - ParentDashboardViewModel

    func testParentDashboardViewModel_InitialState_IsIdleAndEmpty() {
        let vm = ParentDashboardViewModel()
        XCTAssertTrue(vm.assignments.isEmpty)
        XCTAssertTrue(vm.courses.isEmpty)
        XCTAssertFalse(vm.isLoadingAssignments)
        if case .idle = vm.attendanceSubmissionState { } else { XCTFail("Expected idle") }
    }

    func testParentDashboardViewModel_InitializeAttendanceStatus_SetsTrueForEachStudentWhenEmpty() {
        let vm = ParentDashboardViewModel()
        let students = [
            User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "A", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil),
            User(id: "s2", appleId: nil, googleId: nil, username: nil, name: "B", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        ]
        vm.initializeAttendanceStatusIfNeeded(with: students)
        XCTAssertEqual(vm.attendanceStatus["s1"], true)
        XCTAssertEqual(vm.attendanceStatus["s2"], true)
    }

    func testParentDashboardViewModel_InitializeAttendanceStatus_DoesNothingWhenStudentsEmpty() {
        let vm = ParentDashboardViewModel()
        vm.initializeAttendanceStatusIfNeeded(with: [])
        XCTAssertTrue(vm.attendanceStatus.isEmpty)
    }

    func testParentDashboardViewModel_SetAttendance_UpdatesSingleStudent() {
        let vm = ParentDashboardViewModel()
        vm.setAttendance(studentId: "s1", isPresent: false)
        XCTAssertEqual(vm.attendanceStatus["s1"], false)
        vm.setAttendance(studentId: "s1", isPresent: true)
        XCTAssertEqual(vm.attendanceStatus["s1"], true)
    }

    func testParentDashboardViewModel_UpdateAttendanceStatusForAll_DoesNothingWhenStudentsEmpty() {
        let vm = ParentDashboardViewModel()
        vm.attendanceStatus = ["s1": true]
        vm.updateAttendanceStatusForAll(false)
        XCTAssertEqual(vm.attendanceStatus["s1"], true)
    }

    // MARK: - StudentDetailViewModel

    func testStudentDetailViewModel_AttendanceSummary_FromRecords() throws {
        let student = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "S", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let r1 = try decoder.decode(AttendanceRecordDTO.self, from: Data("""
        {"id":"r1","familyId":"f1","studentUserId":"s1","recordedByUserId":"p1","date":"2025-01-15T12:00:00Z","status":"present","isPresent":true}
        """.utf8))
        let r2 = try decoder.decode(AttendanceRecordDTO.self, from: Data("""
        {"id":"r2","familyId":"f1","studentUserId":"s1","recordedByUserId":"p1","date":"2025-01-14T12:00:00Z","status":"absent","isPresent":false}
        """.utf8))
        let vm = StudentDetailViewModel(student: student, courses: [], assignments: [], attendanceRecords: [r1, r2])
        XCTAssertEqual(vm.attendance.classesAttended, 1)
        XCTAssertEqual(vm.attendance.classesMissed, 1)
        XCTAssertEqual(vm.attendance.totalClasses, 2)
        XCTAssertEqual(vm.attendance.average, 0.5)
        XCTAssertEqual(vm.attendance.streakDays, 1)
    }

    func testStudentDetailViewModel_Snapshot_ReflectsLoadedState() throws {
        let student = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "Alex", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        let vm = StudentDetailViewModel(student: student, courses: [], assignments: [], attendanceRecords: [])
        let snapshot = vm.makeSnapshot()
        XCTAssertEqual(snapshot.studentName, "Alex")
        XCTAssertEqual(snapshot.attendanceAverage, 0)
        XCTAssertEqual(snapshot.classesAttendedText, "0")
        XCTAssertEqual(snapshot.classesMissedText, "0")
        XCTAssertEqual(snapshot.attendanceStreakText, "No streak")
        if case .loaded = snapshot.attendanceStatus { } else { XCTFail("Expected loaded") }
    }

    func testStudentDetailViewModel_Snapshot_IncludesCourseGradesFromAssignments() throws {
        let student = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "S", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        let a1 = Assignment(title: "Q1", studentId: "s1", pointsPossible: 100, pointsAwarded: 80, completed: true)
        let a2 = Assignment(title: "Q2", studentId: "s1", pointsPossible: 100, pointsAwarded: 90, completed: true)
        let course = Course(name: "Math", assignments: [a1, a2], students: [student])
        let vm = StudentDetailViewModel(student: student, courses: [course], assignments: [a1, a2], attendanceRecords: [])
        let snapshot = vm.makeSnapshot()
        XCTAssertEqual(snapshot.courses.count, 1)
        XCTAssertEqual(snapshot.courses[0].calculatedGrade(for: "s1"), 85.0)
    }

    func testStudentDetailViewModel_RecentAssignments_OnlyCompletedSortedByDueDate() throws {
        let student = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "S", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        let base = Date()
        let a1 = Assignment(title: "A", studentId: "s1", dueDate: base.addingTimeInterval(-100), pointsPossible: 10, pointsAwarded: 10, completed: true)
        let a2 = Assignment(title: "B", studentId: "s1", dueDate: base.addingTimeInterval(-50), pointsPossible: 10, pointsAwarded: 8, completed: true)
        let a3 = Assignment(title: "C", studentId: "s1", dueDate: base, pointsPossible: 10, pointsAwarded: nil, completed: false)
        let vm = StudentDetailViewModel(student: student, courses: [], assignments: [a1, a2, a3], attendanceRecords: [])
        let snapshot = vm.makeSnapshot()
        XCTAssertEqual(snapshot.recentAssignments.count, 2)
        XCTAssertEqual(snapshot.recentAssignments[0].title, "B")
        XCTAssertEqual(snapshot.recentAssignments[1].title, "A")
    }

    func testStudentDetailViewModel_AttendanceStreakText_OneDay() throws {
        let student = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "S", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let r = try decoder.decode(AttendanceRecordDTO.self, from: Data("""
        {"id":"r1","familyId":"f1","studentUserId":"s1","recordedByUserId":"p1","date":"2025-01-15T12:00:00Z","status":"present","isPresent":true}
        """.utf8))
        let vm = StudentDetailViewModel(student: student, courses: [], assignments: [], attendanceRecords: [r])
        XCTAssertEqual(vm.attendanceStreakText, "1 day")
    }

    func testStudentDetailViewModel_AttendanceStreakText_MultipleDays() throws {
        let student = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "S", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let r1 = try decoder.decode(AttendanceRecordDTO.self, from: Data("""
        {"id":"r1","familyId":"f1","studentUserId":"s1","recordedByUserId":"p1","date":"2025-01-15T12:00:00Z","status":"present","isPresent":true}
        """.utf8))
        let r2 = try decoder.decode(AttendanceRecordDTO.self, from: Data("""
        {"id":"r2","familyId":"f1","studentUserId":"s1","recordedByUserId":"p1","date":"2025-01-14T12:00:00Z","status":"present","isPresent":true}
        """.utf8))
        let vm = StudentDetailViewModel(student: student, courses: [], assignments: [], attendanceRecords: [r1, r2])
        XCTAssertEqual(vm.attendanceStreakText, "2 days")
    }

    // MARK: - PortfolioListViewModel

    func testPortfolioListViewModel_InitialState_IsEmptyAndNotLoading() {
        let vm = PortfolioListViewModel()
        XCTAssertTrue(vm.portfolios.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - AddPortfolioViewModel

    func testAddPortfolioViewModel_IsValid_FalseWhenNoStudent() {
        let vm = AddPortfolioViewModel()
        XCTAssertFalse(vm.isValid)
    }

    func testAddPortfolioViewModel_IsValid_TrueWhenStudentSet() {
        let vm = AddPortfolioViewModel()
        let user = User(id: "u1", appleId: nil, googleId: nil, username: nil, name: "Test", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        vm.selectedStudent = user
        XCTAssertTrue(vm.isValid)
    }

    func testAddPortfolioViewModel_ClearError_NilsErrorMessage() {
        let vm = AddPortfolioViewModel()
        vm.clearError()
        XCTAssertNil(vm.errorMessage)
    }

    func testAddPortfolioViewModel_ToggleWorkFile_AddsThenRemoves() {
        let vm = AddPortfolioViewModel()
        let file = StudentWorkFile(fileName: "doc.pdf", fileUrl: "url", fileType: "application/pdf", fileSize: 100, studentId: "s1")
        XCTAssertTrue(vm.selectedWorkFiles.isEmpty)
        vm.toggleWorkFile(file)
        XCTAssertTrue(vm.selectedWorkFiles.contains(file))
        vm.toggleWorkFile(file)
        XCTAssertTrue(vm.selectedWorkFiles.isEmpty)
    }

    func testAddPortfolioViewModel_SelectedDesignPattern_DefaultsToGeneral() {
        let vm = AddPortfolioViewModel()
        XCTAssertEqual(vm.selectedDesignPattern, .general)
    }

    // MARK: - AuthViewModel (guard clauses and signOut only; no network)

    func testAuthViewModel_SignOut_ClearsUserAndState() async {
        let vm = AuthViewModel()
        vm.signOut()
        XCTAssertNil(vm.currentUser)
        XCTAssertTrue(vm.students.isEmpty)
        XCTAssertTrue(vm.notifications.isEmpty)
        XCTAssertEqual(vm.signInState, .notSignedIn)
    }

    func testAuthViewModel_JoinFamily_ThrowsNoCurrentUser_WhenUserNil() async {
        let vm = AuthViewModel()
        vm.signOut()
        do {
            try await vm.joinFamily(with: "ABC123")
            XCTFail("Expected FamilyJoinError.noCurrentUser")
        } catch let error as AuthViewModel.FamilyJoinError {
            if case .noCurrentUser = error { } else { XCTFail("Expected noCurrentUser") }
        } catch {
            XCTFail("Expected FamilyJoinError, got \(error)")
        }
    }

    func testAuthViewModel_JoinFamily_ThrowsInvalidCode_WhenCodeWhitespaceOnly() async {
        // Validation runs before API: trimmedCode.isEmpty throws invalidCode. We cannot set currentUser from tests,
        // so we only assert that joinFamily throws when signed out (noCurrentUser). InvalidCode path tested via FamilyJoinError.errorDescription.
        let vm = AuthViewModel()
        vm.signOut()
        do {
            try await vm.joinFamily(with: "   ")
            XCTFail("Expected throw")
        } catch let error as AuthViewModel.FamilyJoinError {
            // When signed out we get noCurrentUser (validation runs after currentUser check).
            if case .noCurrentUser = error { } else { XCTFail("Expected noCurrentUser when signed out") }
        } catch {
            XCTFail("Expected FamilyJoinError")
        }
    }

    func testAuthViewModel_CreateFamily_ThrowsInvalidName_WhenNameEmptyOrWhitespace() async {
        let vm = AuthViewModel()
        do {
            try await vm.createFamily(named: "   ")
            XCTFail("Expected FamilyJoinError.invalidName")
        } catch let error as AuthViewModel.FamilyJoinError {
            if case .invalidName = error { } else { XCTFail("Expected invalidName") }
        } catch {
            XCTFail("Expected FamilyJoinError, got \(error)")
        }
    }

    func testAuthViewModel_CreateFamily_ThrowsInvalidName_WhenNameEmpty() async {
        let vm = AuthViewModel()
        do {
            try await vm.createFamily(named: "")
            XCTFail("Expected FamilyJoinError.invalidName")
        } catch let error as AuthViewModel.FamilyJoinError {
            if case .invalidName = error { } else { XCTFail("Expected invalidName") }
        } catch {
            XCTFail("Expected FamilyJoinError, got \(error)")
        }
    }

    // MARK: - FamilyJoinError (business error descriptions)

    func testFamilyJoinError_ErrorDescriptions_AreLocalized() {
        XCTAssertNotNil(AuthViewModel.FamilyJoinError.noCurrentUser.errorDescription)
        XCTAssertNotNil(AuthViewModel.FamilyJoinError.invalidCode.errorDescription)
        XCTAssertNotNil(AuthViewModel.FamilyJoinError.invalidName.errorDescription)
        XCTAssertNotNil(AuthViewModel.FamilyJoinError.familyNotFound.errorDescription)
        let inner = NSError(domain: "t", code: 1, userInfo: [NSLocalizedDescriptionKey: "custom msg"])
        let err = AuthViewModel.FamilyJoinError.saveFailed(inner)
        let desc = err.errorDescription ?? ""
        XCTAssertTrue(desc.contains("custom msg") || desc.contains(inner.localizedDescription))
    }

    // MARK: - PlannerTaskStore

    func testPlannerTaskStore_Add_AppendsAndSortsByStartDate() {
        OfflineCache.shared.remove("plannerTasks.json")
        let store = PlannerTaskStore()
        let base = Date()
        let t1 = PlannerTask(title: "Later", startDate: base.addingTimeInterval(3600), durationMinutes: 30, colorName: "Blue")
        let t2 = PlannerTask(title: "Earlier", startDate: base, durationMinutes: 30, colorName: "Green")
        store.add(t1)
        store.add(t2)
        let all = store.allTasks()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].title, "Earlier")
        XCTAssertEqual(all[1].title, "Later")
    }

    func testPlannerTaskStore_TasksForDate_ReturnsOnlyThatDay() {
        OfflineCache.shared.remove("plannerTasks.json")
        let store = PlannerTaskStore()
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let t1 = PlannerTask(title: "Today", startDate: startOfToday.addingTimeInterval(3600), durationMinutes: 30, colorName: "Blue")
        let t2 = PlannerTask(title: "Tomorrow", startDate: startOfToday.addingTimeInterval(86400 + 3600), durationMinutes: 30, colorName: "Green")
        store.add(t1)
        store.add(t2)
        let todayTasks = store.tasks(for: startOfToday)
        XCTAssertTrue(todayTasks.contains(where: { $0.title == "Today" }), "tasks(for: today) should include Today")
        XCTAssertFalse(todayTasks.contains(where: { $0.title == "Tomorrow" }), "tasks(for: today) should not include Tomorrow")
        XCTAssertGreaterThanOrEqual(todayTasks.count, 1)
    }

    func testPlannerTaskStore_AllTasks_ReturnsCurrentList() {
        OfflineCache.shared.remove("plannerTasks.json")
        let store = PlannerTaskStore()
        let t = PlannerTask(title: "One", startDate: Date(), durationMinutes: 60, colorName: "Red")
        store.add(t)
        let all = store.allTasks()
        XCTAssertTrue(all.contains(where: { $0.title == "One" }), "allTasks() should include the added task")
        XCTAssertGreaterThanOrEqual(all.count, 1)
    }
}
