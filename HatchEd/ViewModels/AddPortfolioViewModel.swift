//
//  AddPortfolioViewModel.swift
//  HatchEd
//
//  MVVM: ViewModel for add-portfolio form.
//

import Foundation
import SwiftUI

@MainActor
final class AddPortfolioViewModel: ObservableObject {
    @Published var selectedStudent: User?
    @Published var selectedDesignPattern: PortfolioDesignPattern = .general
    @Published var selectedWorkFiles: Set<StudentWorkFile> = []
    @Published var studentRemarks = ""
    @Published var instructorRemarks = ""
    @Published var aboutMe = ""
    @Published var achievementsAndAwards = ""
    @Published var attendanceNotes = ""
    @Published var extracurricularActivities = ""
    @Published var serviceLog = ""

    @Published private(set) var availableWorkFiles: [StudentWorkFile] = []
    @Published private(set) var isLoadingFiles = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let api = APIClient.shared

    var isValid: Bool { selectedStudent != nil }

    func loadStudentWorkFiles(studentId: String?) async {
        guard let studentId = studentId else {
            availableWorkFiles = []
            return
        }
        isLoadingFiles = true
        defer { isLoadingFiles = false }
        do {
            availableWorkFiles = try await api.fetchStudentWorkFiles(studentId: studentId)
        } catch {
            print("Failed to load student work files: \(error)")
            availableWorkFiles = []
        }
    }

    func toggleWorkFile(_ file: StudentWorkFile) {
        if selectedWorkFiles.contains(file) {
            selectedWorkFiles.remove(file)
        } else {
            selectedWorkFiles.insert(file)
        }
    }

    func createPortfolio() async throws -> Portfolio {
        guard let student = selectedStudent else {
            throw NSError(domain: "AddPortfolio", code: -1, userInfo: [NSLocalizedDescriptionKey: "Select a student"])
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let courses = try await api.fetchCourses()
            let studentCourses = courses.filter { $0.students.contains(where: { $0.id == student.id }) }
            let reportCardData = try? JSONEncoder().encode(studentCourses)
            let reportCardSnapshot = reportCardData.flatMap { String(data: $0, encoding: .utf8) }
            let sectionData = PortfolioSectionData(
                aboutMe: aboutMe.isEmpty ? nil : aboutMe,
                achievementsAndAwards: achievementsAndAwards.isEmpty ? nil : achievementsAndAwards,
                attendanceNotes: attendanceNotes.isEmpty ? nil : attendanceNotes,
                extracurricularActivities: extracurricularActivities.isEmpty ? nil : extracurricularActivities,
                serviceLog: serviceLog.isEmpty ? nil : serviceLog
            )
            let portfolio = try await api.createPortfolio(
                studentId: student.id,
                studentName: student.name ?? "Student",
                designPattern: selectedDesignPattern,
                studentWorkFileIds: Array(selectedWorkFiles.map { $0.id }),
                studentRemarks: studentRemarks.isEmpty ? nil : studentRemarks,
                instructorRemarks: instructorRemarks.isEmpty ? nil : instructorRemarks,
                reportCardSnapshot: reportCardSnapshot,
                sectionData: sectionData
            )
            return portfolio
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            throw error
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
