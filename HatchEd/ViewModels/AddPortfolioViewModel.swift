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
    @Published var selectedAudience: PortfolioAudience = .family
    @Published var selectedWorkFiles: Set<StudentWorkFile> = []
    /// Section key -> work file ID for user-provided photos per section (e.g. "aboutMe" -> "fileId").
    @Published var sectionPhotoFileIds: [String: String] = [:]
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
    /// Warnings from the server after a successful create (e.g. AI compilation failed).
    @Published var createWarnings: [String] = []

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
            let files = try await api.fetchStudentWorkFiles(studentId: studentId)
            availableWorkFiles = files
            // Auto-include all best-work files unless parent explicitly removes
            selectedWorkFiles = Set(files)
            // Keep only section photos that reference files still in the list
            let validIds = Set(files.map { $0.id })
            sectionPhotoFileIds = sectionPhotoFileIds.filter { validIds.contains($0.value) }
        } catch {
            print("Failed to load student work files: \(error)")
            availableWorkFiles = []
            selectedWorkFiles = []
        }
    }

    func toggleWorkFile(_ file: StudentWorkFile) {
        if selectedWorkFiles.contains(file) {
            selectedWorkFiles.remove(file)
            sectionPhotoFileIds = sectionPhotoFileIds.filter { $0.value != file.id }
        } else {
            selectedWorkFiles.insert(file)
        }
    }

    func setSectionPhoto(sectionKey: String, fileId: String?) {
        if let fileId = fileId {
            sectionPhotoFileIds[sectionKey] = fileId
        } else {
            sectionPhotoFileIds.removeValue(forKey: sectionKey)
        }
    }

    /// Uploads a photo from the device and returns the created StudentWorkFile.
    func uploadSectionPhoto(studentId: String, data: Data, fileName: String, mimeType: String) async throws -> StudentWorkFile {
        try await api.uploadStudentWorkFile(
            studentId: studentId,
            fileName: fileName,
            fileData: data,
            fileType: mimeType
        )
    }

    func sectionPhotoFileId(for sectionKey: String) -> String? {
        sectionPhotoFileIds[sectionKey]
    }

    var imageWorkFiles: [StudentWorkFile] {
        availableWorkFiles.filter { $0.fileType.hasPrefix("image/") }
    }

    static let sectionsWithPhotos: [(key: String, title: String)] = [
        ("aboutMe", "About Me"),
        ("achievementsAndAwards", "Achievements and Awards"),
        ("attendanceNotes", "Attendance Notes"),
        ("extracurricularActivities", "Extracurricular Activities"),
        ("serviceLog", "Service Log")
    ]

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
            let (portfolio, warnings) = try await api.createPortfolio(
                studentId: student.id,
                studentName: student.name ?? "Student",
                audience: selectedAudience,
                studentWorkFileIds: Array(selectedWorkFiles.map { $0.id }),
                sectionPhotoFileIds: sectionPhotoFileIds.isEmpty ? nil : sectionPhotoFileIds,
                studentRemarks: studentRemarks.isEmpty ? nil : studentRemarks,
                instructorRemarks: instructorRemarks.isEmpty ? nil : instructorRemarks,
                reportCardSnapshot: reportCardSnapshot,
                sectionData: sectionData
            )
            createWarnings = warnings
            return portfolio
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            throw error
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func setError(_ message: String?) {
        errorMessage = message
    }
}
