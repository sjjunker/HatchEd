//
//  Resources.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI
import UniformTypeIdentifiers

struct Resources: View {
    @EnvironmentObject private var signInManager: AppleSignInManager
    @State private var studentWorkFiles: [String: [StudentWorkFile]] = [:] // Keyed by studentId
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedStudent: User?
    @State private var showingFilePicker = false
    
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
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.item], // Allow all file types
            allowsMultipleSelection: true
        ) { result in
            Task {
                await handleFileSelection(result)
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
    private func handleFileSelection(_ result: Result<[URL], Error>) async {
        guard let student = selectedStudent ?? signInManager.students.first else { return }
        
        switch result {
        case .success(let urls):
            for url in urls {
                do {
                    // Start accessing the security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else {
                        print("Failed to access security-scoped resource: \(url)")
                        continue
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    // Read file data
                    let fileData = try Data(contentsOf: url)
                    
                    // Get file name from URL
                    let fileName = url.lastPathComponent
                    
                    // Determine file type from URL extension
                    let fileExtension = url.pathExtension.lowercased()
                    let fileType = getMimeType(for: fileExtension)
                    
                    print("[Resources] Uploading file - name: \(fileName), type: \(fileType), size: \(fileData.count) bytes")
                    
                    let uploadedFile = try await api.uploadStudentWorkFile(
                        studentId: student.id,
                        fileName: fileName,
                        fileData: fileData,
                        fileType: fileType
                    )
                    
                    print("[Resources] File uploaded successfully: \(uploadedFile.fileName)")
                } catch {
                    print("[Resources] Failed to upload file \(url.lastPathComponent): \(error.localizedDescription)")
                    errorMessage = "Failed to upload \(url.lastPathComponent): \(error.localizedDescription)"
                }
            }
            
            // Refresh files after uploads
            await loadStudentWorkFiles()
            
        case .failure(let error):
            print("[Resources] File picker error: \(error.localizedDescription)")
            errorMessage = "Failed to select files: \(error.localizedDescription)"
        }
    }
    
    private func getMimeType(for fileExtension: String) -> String {
        let mimeTypes: [String: String] = [
            "pdf": "application/pdf",
            "doc": "application/msword",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls": "application/vnd.ms-excel",
            "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "ppt": "application/vnd.ms-powerpoint",
            "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "txt": "text/plain",
            "rtf": "application/rtf",
            "zip": "application/zip",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "gif": "image/gif",
            "mp4": "video/mp4",
            "mov": "video/quicktime",
            "mp3": "audio/mpeg",
            "wav": "audio/wav",
            "html": "text/html",
            "css": "text/css",
            "js": "application/javascript",
            "json": "application/json",
            "xml": "application/xml",
            "csv": "text/csv"
        ]
        
        return mimeTypes[fileExtension.lowercased()] ?? "application/octet-stream"
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
        let lowercased = fileType.lowercased()
        if lowercased.contains("image") {
            return "photo"
        } else if lowercased.contains("pdf") {
            return "doc.fill"
        } else if lowercased.contains("text") || lowercased.contains("plain") {
            return "doc.text"
        } else if lowercased.contains("video") {
            return "video.fill"
        } else if lowercased.contains("audio") {
            return "music.note"
        } else if lowercased.contains("spreadsheet") || lowercased.contains("excel") || lowercased.contains("csv") {
            return "tablecells.fill"
        } else if lowercased.contains("presentation") || lowercased.contains("powerpoint") {
            return "rectangle.stack.fill"
        } else if lowercased.contains("zip") || lowercased.contains("archive") {
            return "archivebox.fill"
        } else if lowercased.contains("word") || lowercased.contains("document") {
            return "doc.text.fill"
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

