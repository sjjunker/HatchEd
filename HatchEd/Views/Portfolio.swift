//
//  Portfolio.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PortfolioView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = PortfolioListViewModel()
    @State private var showingAddPortfolio = false
    @State private var selectedPortfolio: Portfolio?
    @State private var studentWorkFilesByStudentId: [String: [StudentWorkFile]] = [:]
    @State private var uploadTargetStudent: User?
    @State private var isUploadingWorkFile = false
    @State private var portfolioPendingDelete: Portfolio?
    @State private var deleteErrorMessage: String?

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
            PortfolioDetailView(
                portfolio: portfolio,
                isStudent: !isParent,
                onDeleted: {
                    Task {
                        await viewModel.loadPortfolios()
                        selectedPortfolio = nil
                    }
                }
            )
        }
        .confirmationDialog(
            "Delete portfolio?",
            isPresented: Binding(
                get: { portfolioPendingDelete != nil },
                set: { if !$0 { portfolioPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let p = portfolioPendingDelete {
                    Task { await deletePortfolioConfirmed(p) }
                }
            }
            Button("Cancel", role: .cancel) {
                portfolioPendingDelete = nil
            }
        } message: {
            if let p = portfolioPendingDelete {
                Text(
                    "This permanently removes “\(p.portfolioLabel) Portfolio” for \(p.studentName), including all AI-generated images for this portfolio. Student work files in Best work are not deleted. This cannot be undone."
                )
            }
        }
        .alert("Could not delete portfolio", isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { deleteErrorMessage = nil }
        } message: {
            if let deleteErrorMessage {
                Text(deleteErrorMessage)
            }
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

    private func deletePortfolioConfirmed(_ portfolio: Portfolio) async {
        portfolioPendingDelete = nil
        do {
            try await APIClient.shared.deletePortfolio(id: portfolio.id)
            if selectedPortfolio?.id == portfolio.id {
                selectedPortfolio = nil
            }
            await viewModel.loadPortfolios()
        } catch {
            deleteErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
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
                PortfolioRow(
                    portfolio: portfolio,
                    canDelete: isParent,
                    onSelect: { selectedPortfolio = portfolio },
                    onDeleteRequest: { portfolioPendingDelete = portfolio }
                )
            }
        }
    }
}

/// First stored image for this portfolio (generated or provided work sample), suitable for list thumbnails.
fileprivate func firstPortfolioThumbnailImageId(for portfolio: Portfolio) -> String? {
    for img in portfolio.generatedImages {
        let id = img.id
        guard id.count == 24, !id.hasPrefix("fallback-"), !id.hasPrefix("missing-"), !id.hasPrefix("failed-") else { continue }
        return id
    }
    return nil
}

/// Small square preview for portfolio list cards (authenticated GET like `PortfolioRemoteImageView`).
private struct PortfolioCardThumbnailView: View {
    let imageId: String?
    var accentColor: Color

    private let size: CGFloat = 60

    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(accentColor.opacity(0.22), lineWidth: 1)
                    )
            } else if imageId == nil {
                placeholderIcon
            } else if loadFailed {
                placeholderIcon
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.hatchEdSecondaryBackground.opacity(0.4))
                    .frame(width: size, height: size)
                    .overlay(ProgressView().scaleEffect(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(accentColor.opacity(0.12), lineWidth: 1)
                    )
            }
        }
        .accessibilityHidden(true)
        .task(id: imageId) {
            await loadThumbnail()
        }
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.hatchEdSecondaryBackground.opacity(0.75))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title3)
                    .foregroundColor(.hatchEdSecondaryText.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accentColor.opacity(0.12), lineWidth: 1)
            )
    }

    @MainActor
    private func loadThumbnail() async {
        image = nil
        loadFailed = false
        guard let imageId, !imageId.isEmpty else { return }
        let url = APIClient.shared.portfolioImageURL(imageId: imageId)
        do {
            var request = URLRequest(url: url)
            request.setValue("image/*", forHTTPHeaderField: "Accept")
            if let token = APIClient.shared.getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let ui = UIImage(data: data) else {
                loadFailed = true
                return
            }
            image = ui
        } catch {
            loadFailed = true
        }
    }
}

private struct PortfolioRow: View {
    let portfolio: Portfolio
    var canDelete: Bool = false
    var onSelect: () -> Void = {}
    var onDeleteRequest: () -> Void = {}

    private var designAccent: Color {
        portfolio.audience.accentColor
    }

    private var thumbnailImageId: String? {
        firstPortfolioThumbnailImageId(for: portfolio)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(designAccent)
                    .frame(width: 4)
                    .padding(.leading, 16)
                PortfolioCardThumbnailView(imageId: thumbnailImageId, accentColor: designAccent)
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(portfolio.studentName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.hatchEdText)
                        Text(portfolio.portfolioLabel + " Portfolio")
                            .font(.subheadline)
                            .foregroundColor(designAccent)
                    }
                    Spacer(minLength: 8)
                    if canDelete {
                        Button {
                            onDeleteRequest()
                        } label: {
                            Image(systemName: "trash")
                                .font(.body)
                                .foregroundColor(.hatchEdCoralAccent)
                                .accessibilityLabel("Delete portfolio")
                        }
                        .buttonStyle(.plain)
                    }
                    if let createdAt = portfolio.createdAt {
                        Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.hatchEdSecondaryText)
                    }
                }
                .padding(.trailing, 16)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.hatchEdCardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(designAccent.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Best work (parent)

private struct BestWorkSectionView: View {
    let student: User
    let files: [StudentWorkFile]
    let onAdd: () -> Void
    let onDelete: (StudentWorkFile) async -> Void

    @State private var isExpanded = true

    private var studentDisplayName: String {
        student.name ?? "Student"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.hatchEdSecondaryText)
                            .frame(width: 12, alignment: .center)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        Text("Best work: \(studentDisplayName)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.hatchEdText)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Best work, \(studentDisplayName)")
                .accessibilityHint(isExpanded ? "Collapse file list" : "Expand file list")

                Button {
                    onAdd()
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.hatchEdAccent)
                }
                .accessibilityLabel("Add best work for \(studentDisplayName)")
            }
            if isExpanded {
                if files.isEmpty {
                    Text("No files yet. Add photos or documents to represent \(studentDisplayName)'s best work.")
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
    
    private var studentDisplayName: String {
        student.name ?? "Student"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add a file or photo for \(studentDisplayName)'s best work.")
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

