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
    @StateObject private var viewModel = AddPortfolioViewModel()
    @State private var showingCreateWarnings = false

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
                Section(header: Text("Design Pattern")) {
                    Picker("Pattern", selection: $viewModel.selectedDesignPattern) {
                        ForEach(PortfolioDesignPattern.allCases) { pattern in
                            Text(pattern.rawValue).tag(pattern)
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
                                if viewModel.selectedWorkFiles.contains(file) && file.fileType.hasPrefix("image/") {
                                    Toggle("Use this photo in portfolio (instead of AI-generated)", isOn: Binding(
                                        get: { viewModel.usePhotoFileIds.contains(file.id) },
                                        set: { _ in viewModel.toggleUsePhotoInPortfolio(file) }
                                    ))
                                    .font(.caption)
                                }
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
                }
                Section(header: Text("Achievements and Awards")) {
                    TextEditor(text: $viewModel.achievementsAndAwards)
                        .frame(minHeight: 100)
                        .placeholder("List academic achievements, awards, recognitions, and honors...", when: $viewModel.achievementsAndAwards)
                }
                Section(header: Text("Attendance Notes")) {
                    TextEditor(text: $viewModel.attendanceNotes)
                        .frame(minHeight: 80)
                        .placeholder("Add any notes about attendance or commitment to learning...", when: $viewModel.attendanceNotes)
                }
                Section(header: Text("Extracurricular Activities")) {
                    TextEditor(text: $viewModel.extracurricularActivities)
                        .frame(minHeight: 100)
                        .placeholder("List extracurricular activities, clubs, sports, and interests...", when: $viewModel.extracurricularActivities)
                }
                Section(header: Text("Service Log")) {
                    TextEditor(text: $viewModel.serviceLog)
                        .frame(minHeight: 100)
                        .placeholder("Document community service, volunteer work, and service learning activities...", when: $viewModel.serviceLog)
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
    
}

