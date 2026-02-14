//
//  ModelTests.swift
//  HatchEdTests
//
//  Unit tests for app models using Swift Testing.
//

import Testing
import Foundation
@testable import HatchEd

struct ModelTests {

    // MARK: - PortfolioDesignPattern

    @Test func portfolioDesignPatternRawValues() {
        #expect(PortfolioDesignPattern.artistic.rawValue == "Artistic")
        #expect(PortfolioDesignPattern.scientific.rawValue == "Scientific")
        #expect(PortfolioDesignPattern.general.rawValue == "General")
        #expect(PortfolioDesignPattern.academic.rawValue == "Academic")
        #expect(PortfolioDesignPattern.creative.rawValue == "Creative")
    }

    @Test func portfolioDesignPatternAllCases() {
        let all = PortfolioDesignPattern.allCases
        #expect(all.count == 5)
        #expect(all.contains(.general))
    }

    // MARK: - Portfolio decoding

    @Test func portfolioDecodesMinimalJSON() throws {
        let json = """
        {
            "id": "portfolio-1",
            "studentId": "student-1",
            "studentName": "Test Student",
            "designPattern": "General",
            "studentWorkFileIds": [],
            "compiledContent": "",
            "snippet": "",
            "generatedImages": []
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let portfolio = try decoder.decode(Portfolio.self, from: data)
        #expect(portfolio.id == "portfolio-1")
        #expect(portfolio.studentId == "student-1")
        #expect(portfolio.studentName == "Test Student")
        #expect(portfolio.designPattern == .general)
        #expect(portfolio.studentWorkFileIds.isEmpty)
        #expect(portfolio.compiledContent == "")
        #expect(portfolio.snippet == "")
        #expect(portfolio.generatedImages.isEmpty)
    }

    @Test func portfolioDecodesWithSectionData() throws {
        let json = """
        {
            "id": "p2",
            "studentId": "s2",
            "studentName": "Jane",
            "designPattern": "Artistic",
            "studentWorkFileIds": ["f1"],
            "sectionData": {
                "aboutMe": "Likes art",
                "achievementsAndAwards": null,
                "attendanceNotes": null,
                "extracurricularActivities": null,
                "serviceLog": null
            },
            "compiledContent": "Content",
            "snippet": "Snippet",
            "generatedImages": []
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let portfolio = try decoder.decode(Portfolio.self, from: data)
        #expect(portfolio.studentName == "Jane")
        #expect(portfolio.designPattern == .artistic)
        #expect(portfolio.sectionData?.aboutMe == "Likes art")
        #expect(portfolio.compiledContent == "Content")
        #expect(portfolio.snippet == "Snippet")
    }

    @Test func portfolioDecodesWithGeneratedImages() throws {
        let json = """
        {
            "id": "p3",
            "studentId": "s3",
            "studentName": "Bob",
            "designPattern": "General",
            "studentWorkFileIds": [],
            "compiledContent": "",
            "snippet": "",
            "generatedImages": [
                { "id": "img1", "description": "A photo" }
            ]
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let portfolio = try decoder.decode(Portfolio.self, from: data)
        #expect(portfolio.generatedImages.count == 1)
        #expect(portfolio.generatedImages[0].id == "img1")
        #expect(portfolio.generatedImages[0].description == "A photo")
    }

    // MARK: - User

    @Test func userDecodes() throws {
        let json = """
        {
            "id": "user-1",
            "name": "Parent User",
            "role": "parent",
            "familyId": "family-1"
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let user = try decoder.decode(User.self, from: data)
        #expect(user.id == "user-1")
        #expect(user.name == "Parent User")
        #expect(user.role == "parent")
        #expect(user.familyId == "family-1")
        #expect(user.isParent == true)
        #expect(user.isStudent == false)
    }

    @Test func userRequiresFamilyWhenStudentWithoutFamilyId() {
        let user = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: nil, email: nil, role: "student", familyId: nil, createdAt: nil, updatedAt: nil)
        #expect(user.requiresFamily == true)
    }

    @Test func userDoesNotRequireFamilyWhenStudentWithFamilyId() {
        let user = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: nil, email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        #expect(user.requiresFamily == false)
    }

    // MARK: - PortfolioSectionData

    @Test func portfolioSectionDataEncodeDecode() throws {
        let section = PortfolioSectionData(
            aboutMe: "About",
            achievementsAndAwards: "Awards",
            attendanceNotes: nil,
            extracurricularActivities: "Sports",
            serviceLog: nil
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(section)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PortfolioSectionData.self, from: data)
        #expect(decoded.aboutMe == "About")
        #expect(decoded.achievementsAndAwards == "Awards")
        #expect(decoded.extracurricularActivities == "Sports")
    }

    // MARK: - PortfolioImage

    @Test func portfolioImageInit() {
        let img = PortfolioImage(id: "i1", description: "Desc")
        #expect(img.id == "i1")
        #expect(img.description == "Desc")
    }

    // MARK: - StudentWorkFile

    @Test func studentWorkFileHashableForSet() {
        let f1 = StudentWorkFile(fileName: "a.pdf", fileUrl: "url1", fileType: "application/pdf", fileSize: 100, studentId: "s1")
        let f2 = StudentWorkFile(fileName: "b.pdf", fileUrl: "url2", fileType: "application/pdf", fileSize: 200, studentId: "s1")
        var set: Set<StudentWorkFile> = [f1, f2]
        #expect(set.count == 2)
        set.insert(f1)
        #expect(set.count == 2)
    }

    @Test func portfolioDecodesWhenGeneratedImagesInvalid() throws {
        let json = """
        {
            "id": "p4",
            "studentId": "s4",
            "studentName": "Pat",
            "designPattern": "Creative",
            "compiledContent": "",
            "snippet": "",
            "generatedImages": {}
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let portfolio = try decoder.decode(Portfolio.self, from: data)
        #expect(portfolio.generatedImages.isEmpty)
        #expect(portfolio.studentName == "Pat")
    }

    @Test func portfolioEncodeDecodeRoundTrip() throws {
        let portfolio = Portfolio(
            studentId: "s1",
            studentName: "Test",
            designPattern: .academic,
            studentWorkFileIds: ["f1"],
            compiledContent: "Content",
            snippet: "Snippet",
            generatedImages: [PortfolioImage(id: "img1", description: "D")]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(portfolio)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Portfolio.self, from: data)
        #expect(decoded.id == portfolio.id)
        #expect(decoded.studentName == portfolio.studentName)
        #expect(decoded.compiledContent == portfolio.compiledContent)
        #expect(decoded.generatedImages.count == 1)
        #expect(decoded.generatedImages[0].id == "img1")
    }

    // MARK: - Assignment

    @Test func assignmentIsCompletedWhenCompletedTrue() {
        let a = Assignment(title: "T", studentId: "s1", pointsPossible: nil, pointsAwarded: nil, completed: true)
        #expect(a.isCompleted == true)
    }

    @Test func assignmentIsCompletedWhenPointsAwardedSet() {
        let a = Assignment(title: "T", studentId: "s1", pointsPossible: 100, pointsAwarded: 80, completed: false)
        #expect(a.isCompleted == true)
    }

    @Test func assignmentNotCompletedWhenNoPointsOrCompletedFalse() {
        let a = Assignment(title: "T", studentId: "s1", pointsPossible: 100, pointsAwarded: nil, completed: false)
        #expect(a.isCompleted == false)
    }

    @Test func assignmentDecodesFromJSON() throws {
        let json = """
        {"id": "a1", "title": "Essay", "studentId": "s1", "dueDate": null, "pointsPossible": 100, "pointsAwarded": 85, "questions": [], "completed": false}
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let a = try decoder.decode(Assignment.self, from: data)
        #expect(a.id == "a1")
        #expect(a.title == "Essay")
        #expect(a.pointsPossible == 100)
        #expect(a.pointsAwarded == 85)
        #expect(a.isCompleted == true)
    }

    // MARK: - Course

    @Test func courseInitAndProperties() {
        let student = User(id: "s1", appleId: nil, googleId: nil, username: nil, name: "S", email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        let course = Course(name: "Math", assignments: [], grade: 90, students: [student])
        #expect(course.name == "Math")
        #expect(course.grade == 90)
        #expect(course.student.id == "s1")
    }

    // MARK: - Family

    @Test func familyDecodesFromJSON() throws {
        let json = """
        {"id": "f1", "name": "Smith", "joinCode": "ABC123", "members": ["u1", "u2"], "createdAt": null, "updatedAt": null}
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let family = try decoder.decode(Family.self, from: data)
        #expect(family.id == "f1")
        #expect(family.name == "Smith")
        #expect(family.joinCode == "ABC123")
        #expect(family.members.count == 2)
    }

    // MARK: - Notification

    @Test func notificationDecodesFromJSON() throws {
        let json = """
        {"id": "n1", "title": "Hello", "body": "World", "userId": "u1", "read": false}
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let n = try decoder.decode(Notification.self, from: data)
        #expect(n.id == "n1")
        #expect(n.title == "Hello")
        #expect(n.body == "World")
        #expect(n.read == false)
    }

    // MARK: - PlannerTask

    @Test func plannerTaskInitAndColor() {
        let task = PlannerTask(title: "Study", startDate: Date(), durationMinutes: 30, colorName: "Green")
        #expect(task.title == "Study")
        #expect(task.durationMinutes == 30)
        #expect(task.colorName == "Green")
        _ = task.color
    }

    @Test func plannerTaskColorForKnownName() {
        let c = PlannerTask.color(for: "Blue")
        #expect(PlannerTask.colorOptions.first(where: { $0.name == "Blue" })?.name == "Blue")
        _ = c
    }

    @Test func plannerTaskColorForUnknownNameReturnsBlue() {
        _ = PlannerTask.color(for: "UnknownColor")
    }

    @Test func plannerTaskColorOptionsCount() {
        #expect(PlannerTask.colorOptions.count == 7)
    }

    // MARK: - Question

    @Test func questionInitAndDecode() throws {
        let q = Question(text: "What is 2+2?", correctAnswer: "4", choices: ["3", "4", "5"], isCorrect: true)
        #expect(q.text == "What is 2+2?")
        #expect(q.correctAnswer == "4")
        #expect(q.isCorrect == true)
        let json = """
        {"id": "\(q.id.uuidString)", "text": "Q?", "choices": [], "correctAnswer": null, "isCorrect": null}
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Question.self, from: data)
        #expect(decoded.text == "Q?")
    }

    // MARK: - User edge cases

    @Test func userIsStudentWhenRoleStudent() {
        let user = User(id: "1", appleId: nil, googleId: nil, username: nil, name: nil, email: nil, role: "student", familyId: "f1", createdAt: nil, updatedAt: nil)
        #expect(user.isStudent == true)
        #expect(user.isParent == false)
    }

    @Test func userRoleNilNotParentOrStudent() {
        let user = User(id: "1", appleId: nil, googleId: nil, username: nil, name: nil, email: nil, role: nil, familyId: nil, createdAt: nil, updatedAt: nil)
        #expect(user.isParent == false)
        #expect(user.isStudent == false)
        #expect(user.requiresFamily == false)
    }

    // MARK: - StudentWorkFile decode

    @Test func studentWorkFileDecodesFromJSON() throws {
        let json = """
        {"id": "f1", "fileName": "doc.pdf", "fileUrl": "https://x.com/f.pdf", "fileType": "application/pdf", "fileSize": 1024, "studentId": "s1"}
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let f = try decoder.decode(StudentWorkFile.self, from: data)
        #expect(f.id == "f1")
        #expect(f.fileName == "doc.pdf")
        #expect(f.fileSize == 1024)
    }

    // MARK: - AttendanceRecordDTO (APIClient)

    @Test func attendanceRecordDTODecodesFromJSON() throws {
        let json = """
        {"id": "ar1", "familyId": "f1", "studentUserId": "s1", "recordedByUserId": "p1", "date": "2025-01-15T12:00:00Z", "status": "present", "isPresent": true}
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(AttendanceRecordDTO.self, from: data)
        #expect(record.id == "ar1")
        #expect(record.familyId == "f1")
        #expect(record.isPresent == true)
        #expect(record.status == "present")
    }

    // MARK: - AppTheme

    @Test func appThemeConstants() {
        #expect(AppTheme.cornerRadius == 12)
        #expect(AppTheme.cardPadding == 16)
        #expect(AppTheme.sectionSpacing == 24)
    }
}
