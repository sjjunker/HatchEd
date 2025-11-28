//
//  Resources.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI
import PhotosUI

struct Resources: View {
    @EnvironmentObject private var signInManager: AppleSignInManager
    @State private var studentWorkFiles: [String: [StudentWorkFile]] = [:] // Keyed by studentId
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedStudent: User?
    @State private var showingFilePicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    private let api = APIClient.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                studentWorkSection
            }
            .padding()
        }
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await loadStudentWorkFiles()
            }
        }
        .refreshable {
            await loadStudentWorkFiles()
        }
        .photosPicker(isPresented: $showingFilePicker, selection: $selectedPhotos, maxSelectionCount: 10)
        .onChange(of: selectedPhotos) { newItems in
            Task {
                await uploadSelectedFiles(newItems)
            }
        }
    }
    
    private var studentWorkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.hatchEdAccent)
                Text("Student Work")
                    .font(.headline)
                    .foregroundColor(.hatchEdText)
                Spacer()
                Button {
                    showingFilePicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.hatchEdAccent)
                        .font(.title2)
                }
            }
            
            if signInManager.students.isEmpty {
                Text("No students available")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding()
            } else {
                ForEach(signInManager.students) { student in
                    StudentWorkFilesList(
                        student: student,
                        files: studentWorkFiles[student.id] ?? [],
                        onUpload: {
                            selectedStudent = student
                            showingFilePicker = true
                        }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.hatchEdCardBackground)
        )
    }
    
    @MainActor
    private func loadStudentWorkFiles() async {
        isLoading = true
        errorMessage = nil
        
        var allFiles: [String: [StudentWorkFile]] = [:]
        
        for student in signInManager.students {
            do {
                let files = try await api.fetchStudentWorkFiles(studentId: student.id)
                allFiles[student.id] = files
            } catch {
                print("Failed to load files for student \(student.id): \(error)")
            }
        }
        
        studentWorkFiles = allFiles
        isLoading = false
    }
    
    @MainActor
    private func uploadSelectedFiles(_ items: [PhotosPickerItem]) async {
        guard let student = selectedStudent ?? signInManager.students.first else { return }
        
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    // Get file type from item
                    let contentType = item.supportedContentTypes.first
                    let fileExtension = contentType?.preferredFilenameExtension ?? "dat"
                    let fileName = "file_\(UUID().uuidString).\(fileExtension)"
                    let fileType = contentType?.identifier ?? "application/octet-stream"
                    
                    let uploadedFile = try await api.uploadStudentWorkFile(
                        studentId: student.id,
                        fileName: fileName,
                        fileData: data,
                        fileType: fileType
                    )
                    
                    // Refresh files
                    await loadStudentWorkFiles()
                }
            } catch {
                print("Failed to upload file: \(error)")
            }
        }
        
        selectedPhotos = []
    }
}

private struct StudentWorkFilesList: View {
    let student: User
    let files: [StudentWorkFile]
    let onUpload: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(student.name ?? "Student")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.hatchEdText)
                Spacer()
                Button(action: onUpload) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.hatchEdAccent)
                }
            }
            
            if files.isEmpty {
                Text("No files uploaded")
                    .font(.caption)
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding(.leading)
            } else {
                ForEach(files) { file in
                    HStack {
                        Image(systemName: fileIcon(for: file.fileType))
                            .foregroundColor(.hatchEdAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.fileName)
                                .font(.caption)
                                .foregroundColor(.hatchEdText)
                            Text(fileSizeString(file.fileSize))
                                .font(.caption2)
                                .foregroundColor(.hatchEdSecondaryText)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.leading)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdSecondaryBackground)
        )
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

