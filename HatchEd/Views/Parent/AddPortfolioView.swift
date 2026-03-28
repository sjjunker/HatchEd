//
//  AddPortfolioView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//

import SwiftUI
import PhotosUI

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
    @StateObject private var viewModel = AddPortfolioViewModel()
    @State private var showingCreateWarnings = false
    @State private var selectedPhotoForSection: [String: [PhotosPickerItem]] = [:]
    @State private var isUploadingPhotoForSection: [String: Bool] = [:]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Student")) {
                    if !students.isEmpty {
                        Picker("Select Student", selection: Binding(
                            get: { viewModel.selectedStudent?.id },
                            set: { id in
                                viewModel.selectedStudent = students.first { $0.id == id }
                                Task {
                                    await viewModel.loadStudentWorkFiles(studentId: id)
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
                Section(header: Text("Audience"), footer: Text("The portfolio will be tailored for your selected audience—tone, emphasis, and content focus will adapt accordingly.")) {
                    Picker("Audience", selection: $viewModel.selectedAudience) {
                        ForEach(PortfolioAudience.allCases) { audience in
                            Text(audience.rawValue).tag(audience)
                        }
                    }
                }
                Section(header: Text("Student Work")) {
                    if viewModel.isLoadingFiles {
                        ProgressView()
                    } else if viewModel.availableWorkFiles.isEmpty {
                        Text(viewModel.selectedStudent == nil ? "Select a student first" : "No student work files available")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdSecondaryText)
                    } else {
                        ForEach(viewModel.availableWorkFiles) { file in
                            VStack(alignment: .leading, spacing: 8) {
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
                                    if viewModel.selectedWorkFiles.contains(file) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.hatchEdSuccess)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { viewModel.toggleWorkFile(file) }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section(header: Text("Student Remarks")) {
                    TextEditor(text: $viewModel.studentRemarks)
                        .frame(minHeight: 100)
                }
                Section(header: Text("Instructor Remarks")) {
                    TextEditor(text: $viewModel.instructorRemarks)
                        .frame(minHeight: 100)
                }
                Section(header: Text("About Me")) {
                    TextEditor(text: $viewModel.aboutMe)
                        .frame(minHeight: 100)
                        .placeholder("Enter information about the student's interests, goals, and personality...", when: $viewModel.aboutMe)
                    sectionPhotoPicker(sectionKey: "aboutMe")
                }
                Section(header: Text("Achievements and Awards")) {
                    TextEditor(text: $viewModel.achievementsAndAwards)
                        .frame(minHeight: 100)
                        .placeholder("List academic achievements, awards, recognitions, and honors...", when: $viewModel.achievementsAndAwards)
                    sectionPhotoPicker(sectionKey: "achievementsAndAwards")
                }
                Section(header: Text("Attendance Notes")) {
                    TextEditor(text: $viewModel.attendanceNotes)
                        .frame(minHeight: 80)
                        .placeholder("Add any notes about attendance or commitment to learning...", when: $viewModel.attendanceNotes)
                    sectionPhotoPicker(sectionKey: "attendanceNotes")
                }
                Section(header: Text("Extracurricular Activities")) {
                    TextEditor(text: $viewModel.extracurricularActivities)
                        .frame(minHeight: 100)
                        .placeholder("List extracurricular activities, clubs, sports, and interests...", when: $viewModel.extracurricularActivities)
                    sectionPhotoPicker(sectionKey: "extracurricularActivities")
                }
                Section(header: Text("Service Log")) {
                    TextEditor(text: $viewModel.serviceLog)
                        .frame(minHeight: 100)
                        .placeholder("Document community service, volunteer work, and service learning activities...", when: $viewModel.serviceLog)
                    sectionPhotoPicker(sectionKey: "serviceLog")
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
                            do {
                                let portfolio = try await viewModel.createPortfolio()
                                onSave(portfolio)
                                if viewModel.createWarnings.isEmpty {
                                    dismiss()
                                } else {
                                    showingCreateWarnings = true
                                }
                            } catch {
                                // errorMessage set in viewModel
                            }
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                }
            }
            .alert("Portfolio created with issues", isPresented: $showingCreateWarnings) {
                Button("OK") {
                    showingCreateWarnings = false
                    dismiss()
                }
            } message: {
                if !viewModel.createWarnings.isEmpty {
                    Text(viewModel.createWarnings.joined(separator: "\n\n"))
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK") {}
            } message: {
                if let message = viewModel.errorMessage {
                    Text(message)
                }
            }
            .overlay {
                if viewModel.isLoading {
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
            .disabled(viewModel.isLoading)
        }
        .onAppear {
            Task {
                await viewModel.loadStudentWorkFiles(studentId: viewModel.selectedStudent?.id)
            }
        }
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

    @ViewBuilder
    private func sectionPhotoPicker(sectionKey: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotosPicker(
                selection: Binding(
                    get: { selectedPhotoForSection[sectionKey, default: []] },
                    set: { newValue in
                        var copy = selectedPhotoForSection
                        copy[sectionKey] = newValue
                        selectedPhotoForSection = copy
                        if let item = newValue.first {
                            Task { await handlePhotoPicked(sectionKey: sectionKey, item: item) }
                        }
                    }
                ),
                maxSelectionCount: 1,
                matching: .images
            ) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Choose from device photos")
                    if isUploadingPhotoForSection[sectionKey] == true {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(viewModel.selectedStudent == nil || isUploadingPhotoForSection[sectionKey] == true)

            if !viewModel.imageWorkFiles.isEmpty {
                Picker("Or use existing work file", selection: Binding(
                    get: { viewModel.sectionPhotoFileId(for: sectionKey) ?? "" },
                    set: { viewModel.setSectionPhoto(sectionKey: sectionKey, fileId: $0.isEmpty ? nil : $0) }
                )) {
                    Text("None").tag("")
                    ForEach(viewModel.imageWorkFiles, id: \.id) { file in
                        Text(file.fileName).tag(file.id)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private func handlePhotoPicked(sectionKey: String, item: PhotosPickerItem) async {
        guard let studentId = viewModel.selectedStudent?.id else { return }
        await MainActor.run { isUploadingPhotoForSection[sectionKey] = true }
        defer {
            Task { @MainActor in
                isUploadingPhotoForSection[sectionKey] = false
                var copy = selectedPhotoForSection
                copy[sectionKey] = []
                selectedPhotoForSection = copy
            }
        }
        do {
            let loaded = try await loadImageDataFromPhotosPickerItem(item)
            let file = try await viewModel.uploadSectionPhoto(
                studentId: studentId,
                data: loaded.data,
                fileName: "section-photo-\(sectionKey).\(loaded.fileNameSuffix)",
                mimeType: loaded.mimeType
            )
            await viewModel.loadStudentWorkFiles(studentId: studentId)
            await MainActor.run { viewModel.setSectionPhoto(sectionKey: sectionKey, fileId: file.id) }
        } catch {
            await MainActor.run { viewModel.setError(error.localizedDescription) }
        }
    }
}

