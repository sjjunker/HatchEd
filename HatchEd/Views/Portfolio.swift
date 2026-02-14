//
//  Portfolio.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI
import UniformTypeIdentifiers

struct PortfolioView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = PortfolioListViewModel()
    @State private var showingAddPortfolio = false
    @State private var selectedPortfolio: Portfolio?
    @State private var studentWorkFilesByStudentId: [String: [StudentWorkFile]] = [:]
    @State private var uploadTargetStudent: User?
    @State private var isUploadingWorkFile = false

    private var isParent: Bool { authViewModel.currentUser?.role == "parent" }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    if isParent {
                        bestWorkSections
                    }
                    if viewModel.isLoading && viewModel.portfolios.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if viewModel.portfolios.isEmpty {
                        emptyStateView
                    } else {
                        portfoliosList
                    }
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.hatchEdCoralAccent)
                            .padding()
                    }
                }
                .padding()
                .padding(.bottom, isParent ? 80 : 24)
            }
            if isParent {
                Button {
                    showingAddPortfolio = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.hatchEdWhite)
                        .frame(width: 56, height: 56)
                        .background(Color.hatchEdAccent)
                        .clipShape(Circle())
                        .shadow(color: .hatchEdDarkGray.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.loadPortfolios()
                if isParent { await loadAllStudentWorkFiles() }
            }
        }
        .refreshable {
            await viewModel.loadPortfolios()
            if isParent { await loadAllStudentWorkFiles() }
        }
        .sheet(isPresented: $showingAddPortfolio) {
            AddPortfolioView(
                students: authViewModel.students,
                onSave: { _ in
                    Task { await viewModel.loadPortfolios() }
                }
            )
        }
        .onChange(of: showingAddPortfolio) { oldValue, newValue in
            if oldValue == true && newValue == false {
                Task { await viewModel.loadPortfolios() }
            }
        }
        .sheet(item: $selectedPortfolio) { portfolio in
            PortfolioDetailView(portfolio: portfolio, isStudent: !isParent)
        }
        .sheet(item: $uploadTargetStudent) { student in
            UploadBestWorkSheet(student: student) {
                Task { await loadAllStudentWorkFiles() }
                uploadTargetStudent = nil
            }
        }
    }

    private var bestWorkSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Best work")
                .font(.headline)
                .foregroundColor(.hatchEdText)
            ForEach(authViewModel.students) { student in
                BestWorkSectionView(
                    student: student,
                    files: studentWorkFilesByStudentId[student.id] ?? [],
                    onAdd: { uploadTargetStudent = student },
                    onDelete: { file in Task { await deleteWorkFile(file); await loadAllStudentWorkFiles() } }
                )
            }
        }
    }

    private func loadAllStudentWorkFiles() async {
        let api = APIClient.shared
        var result: [String: [StudentWorkFile]] = [:]
        for student in authViewModel.students {
            do {
                let files = try await api.fetchStudentWorkFiles(studentId: student.id)
                result[student.id] = files
            } catch {
                result[student.id] = []
            }
        }
        studentWorkFilesByStudentId = result
    }

    private func deleteWorkFile(_ file: StudentWorkFile) async {
        do {
            try await APIClient.shared.deleteStudentWorkFile(id: file.id)
        } catch {}
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 64))
                .foregroundColor(.hatchEdSecondaryText)
            Text(isParent ? "No portfolios yet" : "No portfolios to view yet")
                .font(.headline)
                .foregroundColor(.hatchEdSecondaryText)
            Text(isParent ? "Tap the + button to create a new portfolio" : "When your parent creates a portfolio, it will appear here.")
                .font(.subheadline)
                .foregroundColor(.hatchEdSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var portfoliosList: some View {
        VStack(spacing: 16) {
            if isParent && !viewModel.portfolios.isEmpty {
                Text("Portfolios")
                    .font(.headline)
                    .foregroundColor(.hatchEdText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(viewModel.portfolios) { portfolio in
                PortfolioRow(portfolio: portfolio)
                    .onTapGesture { selectedPortfolio = portfolio }
            }
        }
    }
}

private struct PortfolioRow: View {
    let portfolio: Portfolio
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.hatchEdWhite)
                    .font(.title3)
                    .padding(8)
                    .background(Color.hatchEdAccent)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(portfolio.studentName)
                        .font(.headline)
                        .foregroundColor(.hatchEdText)
                    
                    Text(portfolio.designPattern.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.hatchEdSecondaryText)
                }
                
                Spacer()
                
                Text(portfolio.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "")
                    .font(.caption)
                    .foregroundColor(.hatchEdSecondaryText)
            }
            
            if !portfolio.snippet.isEmpty {
                Text(portfolio.snippet)
                    .font(.body)
                    .foregroundColor(.hatchEdText)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdCardBackground)
                .shadow(color: Color.hatchEdAccent.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Best work (parent)

private struct BestWorkSectionView: View {
    let student: User
    let files: [StudentWorkFile]
    let onAdd: () -> Void
    let onDelete: (StudentWorkFile) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Best work: \(student.name)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.hatchEdText)
                Spacer()
                Button {
                    onAdd()
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.hatchEdAccent)
                }
            }
            if files.isEmpty {
                Text("No files yet. Add photos or documents to represent \(student.name)'s best work.")
                    .font(.caption)
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(files) { file in
                        HStack {
                            Image(systemName: fileTypeIcon(file.fileType))
                                .foregroundColor(.hatchEdAccent)
                                .frame(width: 24)
                            Text(file.fileName)
                                .font(.caption)
                                .foregroundColor(.hatchEdText)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                Task { await onDelete(file) }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.hatchEdCardBackground)
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdCardBackground.opacity(0.6))
                .shadow(color: Color.hatchEdAccent.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }

    private func fileTypeIcon(_ type: String) -> String {
        if type.hasPrefix("image/") { return "photo" }
        if type.contains("pdf") { return "doc.fill" }
        return "doc"
    }
}

private struct UploadBestWorkSheet: View {
    let student: User
    var onUploaded: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker = false
    @State private var isUploading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add a file or photo for \(student.name)'s best work.")
                    .font(.body)
                    .foregroundColor(.hatchEdText)
                    .multilineTextAlignment(.center)
                    .padding()
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.hatchEdCoralAccent)
                        .padding(.horizontal)
                }
                Button {
                    showingFilePicker = true
                } label: {
                    Label("Choose file or photo", systemImage: "folder.badge.plus")
                        .font(.headline)
                }
                .disabled(isUploading)
                if isUploading {
                    ProgressView()
                        .padding()
                }
                Spacer()
            }
            .navigationTitle("Add best work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.image, .pdf, .plainText, .text, .rtf, .content],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleFileResult(result) }
            }
        }
    }

    private func handleFileResult(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        await MainActor.run { errorMessage = nil; isUploading = true }
        defer { Task { @MainActor in isUploading = false } }
        do {
            let data = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            let mimeType = mimeType(for: url.pathExtension)
            _ = try await APIClient.shared.uploadStudentWorkFile(
                studentId: student.id,
                fileName: fileName,
                fileData: data,
                fileType: mimeType
            )
            onUploaded()
            dismiss()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func mimeType(for ext: String) -> String {
        let lower = ext.lowercased()
        switch lower {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "heic": return "image/heic"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "rtf": return "application/rtf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default: return "application/octet-stream"
        }
    }
}

