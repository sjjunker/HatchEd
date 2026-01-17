//
//  Resources.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct Resources: View {
    @EnvironmentObject private var signInManager: AppleSignInManager
    @State private var studentWorkFiles: [String: [StudentWorkFile]] = [:] // Keyed by studentId
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedStudent: User?
    @State private var showingFilePicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingPhotoPicker = false
    
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
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { oldValue, newValue in
            // Only process if we have new items and the picker was just shown
            if !newValue.isEmpty && newValue.count != oldValue.count {
                Task {
                    await handlePhotoSelection(newValue)
                }
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
                Menu {
                    Button {
                        selectedStudent = nil // Will use first student if none selected
                        showingPhotoPicker = true
                    } label: {
                        Label("Add Photos", systemImage: "photo")
                    }
                    Button {
                        selectedStudent = nil // Will use first student if none selected
                        showingFilePicker = true
                    } label: {
                        Label("Add Files", systemImage: "doc")
                    }
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
                        },
                        onPhotoUpload: { items in
                            Task {
                                await handlePhotoSelection(items, for: student)
                            }
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
    
    @MainActor
    private func handlePhotoSelection(_ items: [PhotosPickerItem], for student: User? = nil) async {
        let targetStudent = student ?? selectedStudent ?? signInManager.students.first
        guard let student = targetStudent else {
            print("[Resources] No student available for photo upload")
            return
        }
        
        print("[Resources] Starting photo upload for student: \(student.name ?? student.id), items: \(items.count)")
        
        var successCount = 0
        var failureCount = 0
        
        for (index, item) in items.enumerated() {
            do {
                print("[Resources] Loading photo \(index + 1) of \(items.count)...")
                
                // Load the image data from the PhotosPickerItem
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    print("[Resources] Failed to load photo data for item \(index + 1)")
                    failureCount += 1
                    continue
                }
                
                print("[Resources] Photo data loaded: \(data.count) bytes")
                
                // Determine image type from data
                let imageType = getImageType(from: data)
                
                // Generate filename with timestamp and index
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileName = "photo_\(timestamp)_\(index + 1).\(imageType.extension)"
                
                // Use the MIME type from image detection
                let fileType = imageType.mimeType
                
                print("[Resources] Uploading photo - name: \(fileName), type: \(fileType), size: \(data.count) bytes")
                
                let uploadedFile = try await api.uploadStudentWorkFile(
                    studentId: student.id,
                    fileName: fileName,
                    fileData: data,
                    fileType: fileType
                )
                
                print("[Resources] Photo uploaded successfully: \(uploadedFile.fileName)")
                successCount += 1
            } catch {
                print("[Resources] Failed to upload photo \(index + 1): \(error.localizedDescription)")
                errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                failureCount += 1
            }
        }
        
        print("[Resources] Photo upload complete - Success: \(successCount), Failed: \(failureCount)")
        
        // Clear selection after upload
        selectedPhotoItems = []
        
        // Refresh files after uploads - add a small delay to ensure server has processed
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        await loadStudentWorkFiles()
        
        if successCount > 0 {
            print("[Resources] Files refreshed after photo upload")
        }
    }
    
    private func getImageType(from data: Data) -> (extension: String, mimeType: String) {
        // Check for common image formats
        if data.count >= 4 {
            let bytes = [UInt8](data.prefix(4))
            
            // PNG signature: 89 50 4E 47
            if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
                return ("png", "image/png")
            }
            
            // JPEG signature: FF D8 FF
            if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
                return ("jpg", "image/jpeg")
            }
            
            // GIF signature: 47 49 46 38
            if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 {
                return ("gif", "image/gif")
            }
        }
        
        // Default to JPEG
        return ("jpg", "image/jpeg")
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
    let onPhotoUpload: ([PhotosPickerItem]) -> Void
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(student.name ?? "Student")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.hatchEdText)
                Spacer()
                Menu {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Add Photos", systemImage: "photo")
                    }
                    Button {
                        onUpload()
                    } label: {
                        Label("Add Files", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.hatchEdAccent)
                }
                .photosPicker(
                    isPresented: $showingPhotoPicker,
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 10,
                    matching: .images
                )
                .onChange(of: selectedPhotoItems) { oldValue, newValue in
                    // Only process if we have new items and the picker was just shown
                    if !newValue.isEmpty && newValue.count != oldValue.count {
                        onPhotoUpload(newValue)
                        // Don't clear here - let the parent handle it after upload
                    }
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

