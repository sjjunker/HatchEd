//
//  AddPortfolioView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//

import SwiftUI

struct TextEditorPlaceholder: ViewModifier {
    var placeholder: String
    @Binding var text: String
    
    func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }
            content
        }
    }
}

extension View {
    func placeholder(_ placeholder: String, when text: Binding<String>) -> some View {
        self.modifier(TextEditorPlaceholder(placeholder: placeholder, text: text))
    }
}

struct AddPortfolioView: View {
    let students: [User]
    let onSave: (Portfolio) -> Void
    
    @Environment(\.dismiss) private var dismiss
    private let api = APIClient.shared
    
    @State private var selectedStudent: User?
    @State private var selectedDesignPattern: PortfolioDesignPattern = .general
    @State private var selectedWorkFiles: Set<StudentWorkFile> = []
    @State private var studentRemarks: String = ""
    @State private var instructorRemarks: String = ""
    @State private var aboutMe: String = ""
    @State private var achievementsAndAwards: String = ""
    @State private var attendanceNotes: String = ""
    @State private var extracurricularActivities: String = ""
    @State private var serviceLog: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var availableWorkFiles: [StudentWorkFile] = []
    @State private var isLoadingFiles = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Student")) {
                    if !students.isEmpty {
                        Picker("Select Student", selection: Binding(
                            get: { selectedStudent?.id },
                            set: { id in
                                selectedStudent = students.first { $0.id == id }
                                Task {
                                    await loadStudentWorkFiles()
                                }
                            }
                        )) {
                            Text("Select a student").tag(nil as String?)
                            ForEach(students) { student in
                                Text(student.name ?? "Student").tag(student.id as String?)
                            }
                        }
                    }
                }
                
                Section(header: Text("Design Pattern")) {
                    Picker("Pattern", selection: $selectedDesignPattern) {
                        ForEach(PortfolioDesignPattern.allCases) { pattern in
                            Text(pattern.rawValue).tag(pattern)
                        }
                    }
                }
                
                Section(header: Text("Student Work")) {
                    if isLoadingFiles {
                        ProgressView()
                    } else if availableWorkFiles.isEmpty {
                        Text(selectedStudent == nil ? "Select a student first" : "No student work files available")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdSecondaryText)
                    } else {
                        ForEach(availableWorkFiles) { file in
                            HStack {
                                Image(systemName: fileIcon(for: file.fileType))
                                    .foregroundColor(.hatchEdAccent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.fileName)
                                        .font(.body)
                                    Text(fileSizeString(file.fileSize))
                                        .font(.caption)
                                        .foregroundColor(.hatchEdSecondaryText)
                                }
                                Spacer()
                                if selectedWorkFiles.contains(file) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.hatchEdSuccess)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedWorkFiles.contains(file) {
                                    selectedWorkFiles.remove(file)
                                } else {
                                    selectedWorkFiles.insert(file)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Student Remarks")) {
                    TextEditor(text: $studentRemarks)
                        .frame(minHeight: 100)
                }
                
                Section(header: Text("Instructor Remarks")) {
                    TextEditor(text: $instructorRemarks)
                        .frame(minHeight: 100)
                }
                
                Section(header: Text("About Me")) {
                    TextEditor(text: $aboutMe)
                        .frame(minHeight: 100)
                        .placeholder("Enter information about the student's interests, goals, and personality...", when: $aboutMe)
                }
                
                Section(header: Text("Achievements and Awards")) {
                    TextEditor(text: $achievementsAndAwards)
                        .frame(minHeight: 100)
                        .placeholder("List academic achievements, awards, recognitions, and honors...", when: $achievementsAndAwards)
                }
                
                Section(header: Text("Attendance Notes")) {
                    TextEditor(text: $attendanceNotes)
                        .frame(minHeight: 80)
                        .placeholder("Add any notes about attendance or commitment to learning...", when: $attendanceNotes)
                }
                
                Section(header: Text("Extracurricular Activities")) {
                    TextEditor(text: $extracurricularActivities)
                        .frame(minHeight: 100)
                        .placeholder("List extracurricular activities, clubs, sports, and interests...", when: $extracurricularActivities)
                }
                
                Section(header: Text("Service Log")) {
                    TextEditor(text: $serviceLog)
                        .frame(minHeight: 100)
                        .placeholder("Document community service, volunteer work, and service learning activities...", when: $serviceLog)
                }
                
                Section(footer: Text("A copy of the current report card will be automatically included. Yearly accomplishments by subject will be generated from course data.")) {
                    EmptyView()
                }
            }
            .navigationTitle("New Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createPortfolio()
                        }
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {}
            } message: {
                if let message = errorMessage {
                    Text(message)
                }
            }
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.hatchEdAccent)
                            
                            Text("Generating Portfolio...")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("This may take a few minutes while we create your portfolio and generate images.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                        )
                        .padding(40)
                    }
                }
            }
            .disabled(isLoading)
        }
        .onAppear {
            Task {
                await loadStudentWorkFiles()
            }
        }
    }
    
    private var isValid: Bool {
        selectedStudent != nil
    }
    
    private func fileIcon(for fileType: String) -> String {
        if fileType.contains("image") {
            return "photo"
        } else if fileType.contains("pdf") {
            return "doc.fill"
        } else if fileType.contains("text") {
            return "doc.text"
        } else {
            return "doc"
        }
    }
    
    private func fileSizeString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    @MainActor
    private func loadStudentWorkFiles() async {
        guard let studentId = selectedStudent?.id else {
            availableWorkFiles = []
            return
        }
        
        isLoadingFiles = true
        do {
            availableWorkFiles = try await api.fetchStudentWorkFiles(studentId: studentId)
        } catch {
            print("Failed to load student work files: \(error)")
            availableWorkFiles = []
        }
        isLoadingFiles = false
    }
    
    @MainActor
    private func createPortfolio() async {
        guard let student = selectedStudent else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current report card
            let courses = try await api.fetchCourses()
            let studentCourses = courses.filter { $0.student.id == student.id }
            let reportCardData = try? JSONEncoder().encode(studentCourses)
            let reportCardSnapshot = reportCardData.flatMap { String(data: $0, encoding: .utf8) }
            
            // Create section data
            let sectionData = PortfolioSectionData(
                aboutMe: aboutMe.isEmpty ? nil : aboutMe,
                achievementsAndAwards: achievementsAndAwards.isEmpty ? nil : achievementsAndAwards,
                attendanceNotes: attendanceNotes.isEmpty ? nil : attendanceNotes,
                extracurricularActivities: extracurricularActivities.isEmpty ? nil : extracurricularActivities,
                serviceLog: serviceLog.isEmpty ? nil : serviceLog
            )
            
            // Create portfolio
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
            
            // Portfolio created successfully - refresh the list and dismiss
            onSave(portfolio)
            dismiss()
        } catch {
            // Only show error if portfolio creation actually failed
            // Don't show errors for compilation warnings since portfolio was still created
            print("[AddPortfolio] Error creating portfolio: \(error)")
            if let apiError = error as? APIError {
                errorMessage = "Failed to create portfolio: \(apiError.localizedDescription)"
            } else {
                errorMessage = "Failed to create portfolio: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
}

