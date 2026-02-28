//
//  Resources.swift
//  HatchEd
//
//  Family resources: user-created folders; file, link, photo, video with custom names; optional link to assignment.
//

import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import AVKit

/// Returns display path for a folder (e.g. "Math > Chapter 1") or "Root" for nil.
private func folderPathString(folderId: String?, in folders: [ResourceFolder]) -> String {
    guard let id = folderId, let folder = folders.first(where: { $0.id == id }) else { return "Root" }
    var names: [String] = []
    var current: ResourceFolder? = folder
    while let f = current {
        names.insert(f.name, at: 0)
        current = f.parentFolderId.flatMap { pid in folders.first { $0.id == pid } }
    }
    return names.joined(separator: " › ")
}

/// Returns set of folder ids that are the given folder or any of its descendants (for cycle prevention).
private func descendantIds(of folderId: String, in folders: [ResourceFolder]) -> Set<String> {
    var result: Set<String> = [folderId]
    for f in folders where f.parentFolderId == folderId {
        result.formUnion(descendantIds(of: f.id, in: folders))
    }
    return result
}

/// Reads file data from a URL (including iCloud-backed URLs) using coordination so the system can resolve the file.
private func readFileData(from url: URL) throws -> Data {
    let coordinator = NSFileCoordinator()
    var coordinatorError: NSError?
    var data: Data?
    coordinator.coordinate(readingItemAt: url, options: .forUploading, error: &coordinatorError) { coordinatedURL in
        data = try? Data(contentsOf: coordinatedURL)
    }
    if let err = coordinatorError { throw err }
    guard let result = data else { throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError, userInfo: [NSLocalizedDescriptionKey: "Could not read file"]) }
    return result
}

/// Transferable for loading image data from PhotosPickerItem (e.g. iCloud Photos).
private struct ImageDataTransfer: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            Self(data: data)
        }
    }
}

private struct FolderDeletionCandidate {
    let folder: ResourceFolder
    let subfolderCount: Int
    let resourceCount: Int
    
    var isNonEmpty: Bool {
        subfolderCount > 0 || resourceCount > 0
    }
}

struct Resources: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var folders: [ResourceFolder] = []
    @State private var resources: [Resource] = []
    @State private var allResources: [Resource] = []
    @State private var currentFolderId: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddActions = false
    @State private var showingAddFolder = false
    @State private var showingAddResource = false
    @State private var newFolderName = ""
    @State private var resourceToEdit: Resource?
    @State private var folderToEdit: ResourceFolder?
    @State private var previewFileURL: URL?
    @State private var previewResourceType: ResourceType?
    @State private var searchText = ""
    @State private var folderDeletionCandidate: FolderDeletionCandidate?
    @State private var showingFolderDeleteSimpleAlert = false
    @State private var showingFolderDeleteSummaryAlert = false
    @State private var showingFolderDeleteTypedSheet = false
    @State private var folderDeleteTypedText = ""
    @State private var pendingFolderAlert: ResourceFolder?
    private let api = APIClient.shared
    
    private var isParent: Bool {
        authViewModel.userRole == "parent"
    }
    
    private var availableStudents: [User] {
        authViewModel.students.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
    }

    private var currentFolder: ResourceFolder? {
        currentFolderId.flatMap { id in folders.first { $0.id == id } }
    }
    
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var currentSubfolders: [ResourceFolder] {
        if isSearching { return [] }
        let inFolder = folders.filter { $0.parentFolderId == currentFolderId }
        return inFolder
    }
    
    private var currentResources: [Resource] {
        guard isSearching else {
            return resources
        }
        return allResources.filter { resource in
            resource.displayName.localizedCaseInsensitiveContains(searchText)
                || resource.type.displayName.localizedCaseInsensitiveContains(searchText)
                || folderPathString(folderId: resource.folderId, in: folders).localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Path from root to current folder; nil = root. First element is nil (Resources), then parent chain, then current.
    private var breadcrumbPath: [(id: String?, folder: ResourceFolder?)] {
        var path: [(id: String?, ResourceFolder?)] = [(nil, nil)]
        var folder = currentFolder
        var chain: [ResourceFolder] = []
        while let f = folder {
            chain.insert(f, at: 0)
            folder = f.parentFolderId.flatMap { pid in folders.first { $0.id == pid } }
        }
        for f in chain {
            path.append((f.id, f))
        }
        return path
    }

    /// Top bar shown when inside a folder: Back button + breadcrumb. Stays visible (safeAreaInset).
    private var breadcrumbBar: some View {
        HStack(spacing: 0) {
            Button {
                currentFolderId = currentFolder?.parentFolderId
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                    Text("Back")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundColor(.accentColor)
                .padding(.trailing, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(breadcrumbPath.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                        Button {
                            currentFolderId = item.id
                        } label: {
                            Text(item.folder?.name ?? "Resources")
                                .font(.subheadline)
                                .fontWeight(index == breadcrumbPath.count - 1 ? .semibold : .regular)
                                .foregroundColor(index == breadcrumbPath.count - 1 ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.hatchEdSecondaryText)
            TextField("Search resources", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.hatchEdSecondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdCardBackground)
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                searchBar
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(currentSubfolders) { folder in
                                FolderRow(
                                    folder: folder,
                                    showsManagementActions: isParent,
                                    onTap: {
                                        if folder.scheduledDeletionAt != nil {
                                            pendingFolderAlert = folder
                                        } else {
                                            currentFolderId = folder.id
                                        }
                                    },
                                    onEdit: { folderToEdit = folder },
                                    onDelete: { beginDeleteFolder(folder) }
                                )
                            }
                            ForEach(currentResources) { resource in
                                ResourceRow(
                                    resource: resource,
                                    detailsText: isSearching
                                        ? "\(resource.type.displayName) • \(folderPathString(folderId: resource.folderId, in: folders))"
                                        : resource.type.displayName,
                                    showsManagementActions: isParent,
                                    onTap: { openResource(resource) },
                                    onEdit: { resourceToEdit = resource },
                                    onDelete: { Task { await deleteResource(resource) } }
                                )
                            }
                            if currentSubfolders.isEmpty && currentResources.isEmpty {
                                Text(isSearching ? "No resources match your search" : "No folders or resources here")
                                    .font(.subheadline)
                                    .foregroundColor(.hatchEdSecondaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 32)
                            }
                        }
                        .padding()
                    }
                }
            }

            if showingAddActions {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingAddActions = false
                        }
                    }
            }

            if isParent {
                VStack(alignment: .trailing, spacing: 10) {
                    if showingAddActions {
                        resourcesAddActionsMenu
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingAddActions.toggle()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title)
                            .foregroundColor(.hatchEdWhite)
                            .padding()
                            .background(Color.hatchEdAccent)
                            .clipShape(Circle())
                            .shadow(radius: 6)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(currentFolder == nil ? "Resources" : currentFolder?.name ?? "Folder")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            if breadcrumbPath.count > 1 {
                breadcrumbBar
            }
        }
        .task(id: currentFolderId) { await load() }
        .refreshable { await load() }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: {
            if let m = errorMessage { Text(m) }
        }
        .alert("Delete Empty Folder?", isPresented: $showingFolderDeleteSimpleAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                guard let candidate = folderDeletionCandidate else { return }
                Task { await executeDeleteFolder(candidate.folder) }
            }
        } message: {
            if let candidate = folderDeletionCandidate {
                Text("Delete \"\(candidate.folder.name)\" now?")
            }
        }
        .alert("Confirm Folder Deletion", isPresented: $showingFolderDeleteSummaryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                folderDeleteTypedText = ""
                showingFolderDeleteTypedSheet = true
            }
        } message: {
            if let candidate = folderDeletionCandidate {
                Text("\"\(candidate.folder.name)\" contains \(candidate.subfolderCount) subfolder(s) and \(candidate.resourceCount) resource(s). It will be archived and permanently deleted in 3 days.")
            }
        }
        .alert(item: $pendingFolderAlert) { folder in
            if isParent {
                return Alert(
                    title: Text("Folder Scheduled for Deletion"),
                    message: Text("This folder will be deleted in \(remainingTimeText(until: folder.scheduledDeletionAt))."),
                    primaryButton: .default(Text("Undo")) {
                        Task { await undoScheduledFolderDeletion(folder) }
                    },
                    secondaryButton: .cancel()
                )
            }
            return Alert(
                title: Text("Folder Scheduled for Deletion"),
                message: Text("This folder will be deleted in \(remainingTimeText(until: folder.scheduledDeletionAt))."),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingFolderDeleteTypedSheet, onDismiss: {
            folderDeleteTypedText = ""
        }) {
            NavigationView {
                Form {
                    if let candidate = folderDeletionCandidate {
                        Section {
                            Text("Type the folder name to confirm deletion scheduling.")
                                .font(.subheadline)
                                .foregroundColor(.hatchEdSecondaryText)
                            Text(candidate.folder.name)
                                .font(.headline)
                                .foregroundColor(.hatchEdText)
                        }
                        Section("Folder Name") {
                            TextField("Enter folder name", text: $folderDeleteTypedText)
                                .textInputAutocapitalization(.never)
                        }
                    }
                }
                .navigationTitle("Confirm Delete")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingFolderDeleteTypedSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Schedule Delete") {
                            guard let candidate = folderDeletionCandidate else { return }
                            showingFolderDeleteTypedSheet = false
                            Task { await executeDeleteFolder(candidate.folder) }
                        }
                        .disabled(folderDeleteTypedText != folderDeletionCandidate?.folder.name)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddFolder) {
            AddFolderSheet(
                name: $newFolderName,
                parentFolderId: currentFolderId,
                folders: folders,
                onSave: {
                    Task {
                        await createFolder()
                        newFolderName = ""
                        showingAddFolder = false
                    }
                },
                onCancel: { showingAddFolder = false }
            )
        }
        .sheet(isPresented: $showingAddResource) {
            AddResourceSheet(
                folderId: currentFolderId,
                assignments: [],
                availableStudents: availableStudents,
                onDismiss: { showingAddResource = false },
                onSaved: {
                    Task { await load() }
                    showingAddResource = false
                },
                errorMessage: $errorMessage
            )
            .environmentObject(authViewModel)
        }
        .sheet(item: $resourceToEdit) { resource in
            EditResourceSheet(
                resource: resource,
                folderId: currentFolderId,
                folders: folders,
                availableStudents: availableStudents,
                onDismiss: { resourceToEdit = nil },
                onSaved: {
                    Task { await load() }
                    resourceToEdit = nil
                },
                errorMessage: $errorMessage
            )
        }
        .sheet(item: $folderToEdit) { folder in
            EditFolderSheet(
                folder: folder,
                folders: folders,
                onDismiss: { folderToEdit = nil },
                onSaved: {
                    Task { await load() }
                    folderToEdit = nil
                },
                errorMessage: $errorMessage
            )
        }
        .sheet(isPresented: Binding(
            get: { previewFileURL != nil },
            set: { if !$0 { if let url = previewFileURL { try? FileManager.default.removeItem(at: url) }; previewFileURL = nil; previewResourceType = nil } }
        )) {
            if let url = previewFileURL {
                ResourcePreviewView(url: url, resourceType: previewResourceType) {
                    if let u = previewFileURL { try? FileManager.default.removeItem(at: u) }
                    previewFileURL = nil
                    previewResourceType = nil
                }
            }
        }
    }

    private var resourcesAddActionsMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                showingAddActions = false
                showingAddFolder = true
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            Divider()
            Button {
                showingAddActions = false
                showingAddResource = true
            } label: {
                Label("Add Resource", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
        }
        .font(.subheadline)
        .foregroundColor(.hatchEdText)
        .frame(width: 210)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdCardBackground)
                .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
        )
    }

    private func load() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let (f, r, all) = try await (
                api.fetchResourceFolders(),
                api.fetchResources(folderId: currentFolderId),
                api.fetchResources(includeAll: true)
            )
            await MainActor.run {
                folders = f
                resources = r
                allResources = all
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func createFolder() async {
        guard !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            _ = try await api.createResourceFolder(name: newFolderName.trimmingCharacters(in: .whitespaces), parentFolderId: currentFolderId)
            await load()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func beginDeleteFolder(_ folder: ResourceFolder) {
        guard isParent else { return }
        let candidate = makeFolderDeletionCandidate(folder)
        folderDeletionCandidate = candidate
        if candidate.isNonEmpty {
            showingFolderDeleteSummaryAlert = true
        } else {
            showingFolderDeleteSimpleAlert = true
        }
    }
    
    private func makeFolderDeletionCandidate(_ folder: ResourceFolder) -> FolderDeletionCandidate {
        let treeIds = folderTreeIds(for: folder.id)
        let subfolderCount = max(0, treeIds.count - 1)
        let treeSet = Set(treeIds)
        let resourceCount = allResources.filter { resource in
            guard let fid = resource.folderId else { return false }
            return treeSet.contains(fid)
        }.count
        return FolderDeletionCandidate(folder: folder, subfolderCount: subfolderCount, resourceCount: resourceCount)
    }
    
    private func folderTreeIds(for rootFolderId: String) -> [String] {
        var result: Set<String> = [rootFolderId]
        var stack: [String] = [rootFolderId]
        while let current = stack.popLast() {
            let children = folders.filter { $0.parentFolderId == current }.map(\.id)
            for child in children where !result.contains(child) {
                result.insert(child)
                stack.append(child)
            }
        }
        return Array(result)
    }
    
    private func remainingTimeText(until scheduledDeletionAt: Date?) -> String {
        guard let target = scheduledDeletionAt else { return "less than 1 minute" }
        let seconds = max(0, Int(target.timeIntervalSinceNow))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(max(1, minutes))m"
    }
    
    private func executeDeleteFolder(_ folder: ResourceFolder) async {
        do {
            try await api.deleteResourceFolder(id: folder.id)
            if currentFolderId == folder.id { currentFolderId = folder.parentFolderId }
            await load()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
    
    private func undoScheduledFolderDeletion(_ folder: ResourceFolder) async {
        do {
            _ = try await api.undoDeleteResourceFolder(id: folder.id)
            await load()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func deleteResource(_ resource: Resource) async {
        do {
            try await api.deleteResource(id: resource.id)
            await load()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func openResource(_ resource: Resource) {
        if resource.type == .link, let u = resource.url, let url = URL(string: u) {
            UIApplication.shared.open(url)
            return
        }
        guard resource.fileUrl != nil else { return }
        Task {
            do {
                let localURL = try await api.downloadResourceFile(resourceId: resource.id, displayName: resource.displayName, mimeType: resource.mimeType)
                await MainActor.run { previewFileURL = localURL; previewResourceType = resource.type }
            } catch {
                await MainActor.run { errorMessage = "Could not open file: \(error.localizedDescription)" }
            }
        }
    }
}

extension Resource: Hashable {
    static func == (lhs: Resource, rhs: Resource) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension ResourceFolder: Hashable {
    static func == (lhs: ResourceFolder, rhs: ResourceFolder) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Rows
private struct FolderRow: View {
    let folder: ResourceFolder
    let showsManagementActions: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var isPendingDeletion: Bool {
        folder.scheduledDeletionAt != nil
    }

    var body: some View {
        HStack {
            Button(action: onTap) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(isPendingDeletion ? .hatchEdSecondaryText : .hatchEdWarning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.name)
                            .foregroundColor(.hatchEdText)
                            .lineLimit(1)
                        if isPendingDeletion {
                            Text("Scheduled for deletion")
                                .font(.caption)
                                .foregroundColor(.hatchEdSecondaryText)
                        }
                    }
                        .foregroundColor(.hatchEdText)
                    Spacer()
                    if isPendingDeletion {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.hatchEdSecondaryText)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(.hatchEdSecondaryText)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.hatchEdCardBackground))
                .opacity(isPendingDeletion ? 0.55 : 1.0)
            }
            .buttonStyle(.plain)
            if showsManagementActions && !isPendingDeletion {
                Menu {
                    Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }
}

private struct ResourceRow: View {
    let resource: Resource
    let detailsText: String
    let showsManagementActions: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showingDelete = false

    var body: some View {
        HStack {
            Button(action: onTap) {
                HStack {
                    Image(systemName: resource.type.systemImage)
                        .foregroundColor(.hatchEdAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resource.displayName)
                            .foregroundColor(.hatchEdText)
                            .lineLimit(1)
                        Text(detailsText)
                            .font(.caption)
                            .foregroundColor(.hatchEdSecondaryText)
                    }
                    Spacer()
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.hatchEdCardBackground))
            }
            .buttonStyle(.plain)
            if showsManagementActions {
                Menu {
                    Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive, action: { showingDelete = true }) { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .confirmationDialog("Delete this resource?", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Add Folder
private struct AddFolderSheet: View {
    @Binding var name: String
    var parentFolderId: String?
    let folders: [ResourceFolder]
    let onSave: () -> Void
    let onCancel: () -> Void

    private var locationLabel: String {
        folderPathString(folderId: parentFolderId, in: folders)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Folder name", text: $name)
                }
                Section {
                    LabeledContent("Location", value: locationLabel)
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: onSave).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
        }
    }
}

// MARK: - Add Resource (type + name + link or file; optional assignment)
private struct AddResourceSheet: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    var folderId: String?
    var assignments: [Assignment]
    var availableStudents: [User]
    let onDismiss: () -> Void
    let onSaved: () -> Void
    @Binding var errorMessage: String?
    @State private var resourceType: ResourceType = .link
    @State private var displayName = ""
    @State private var linkURL = ""
    @State private var selectedAssignmentId: String?
    @State private var isSaving = false
    @State private var showingFilePicker = false
    @State private var assignmentsLoaded: [Assignment] = []
    @State private var pendingFileData: Data?
    @State private var pendingFileName: String?
    @State private var pendingMimeType: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedStudentIds: Set<String> = []
    private let api = APIClient.shared

    var body: some View {
        NavigationView {
            Form {
                Section("Type") {
                    Picker("Type", selection: $resourceType) {
                        ForEach(ResourceType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: resourceType) {
                        pendingFileData = nil
                        pendingFileName = nil
                        pendingMimeType = nil
                        selectedPhotoItems = []
                    }
                }
                Section("Name") {
                    TextField("Name you’ll remember", text: $displayName)
                }
                if resourceType == .link {
                    Section("URL") {
                        TextField("https://...", text: $linkURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                    }
                }
                if resourceType == .file || resourceType == .photo {
                    Section("File") {
                        Button("Choose file (Files, iCloud Drive)") { showingFilePicker = true }
                        if let name = pendingFileName {
                            Text("Selected: \(name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if resourceType == .photo {
                        Section("Photo") {
                            PhotosPicker(
                                selection: $selectedPhotoItems,
                                maxSelectionCount: 1,
                                matching: .images
                            ) {
                                Label("Choose from Photos", systemImage: "photo.on.rectangle.angled")
                            }
                            .onChange(of: selectedPhotoItems) { Task { await loadSelectedPhoto() } }
                        }
                    }
                }
                Section("Link to assignment") {
                    Picker("Assignment", selection: $selectedAssignmentId) {
                        Text("None").tag(nil as String?)
                        ForEach(assignmentsLoaded, id: \.id) { a in
                            Text(a.title).tag(a.id as String?)
                        }
                    }
                }
                if !availableStudents.isEmpty {
                    Section("Assign to students") {
                        ForEach(availableStudents) { student in
                            Toggle(isOn: Binding(
                                get: { selectedStudentIds.contains(student.id) },
                                set: { isOn in
                                    if isOn {
                                        selectedStudentIds.insert(student.id)
                                    } else {
                                        selectedStudentIds.remove(student.id)
                                    }
                                }
                            )) {
                                Text(student.name ?? "Student")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDismiss) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                    .disabled(!isValid || isSaving)
                }
            }
            .onAppear {
                Task { await loadAssignments() }
                selectedStudentIds = Set(availableStudents.map(\.id))
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: resourceType == .photo ? [.image] : [.item],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleFileResult(result) }
            }
        }
    }

    private var isValid: Bool {
        let nameOk = !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        if resourceType == .link {
            return nameOk && !linkURL.trimmingCharacters(in: .whitespaces).isEmpty
        }
        if resourceType == .file || resourceType == .photo {
            return nameOk && pendingFileData != nil
        }
        return nameOk
    }

    private func loadAssignments() async {
        do {
            assignmentsLoaded = try await api.fetchAssignments()
        } catch {}
    }

    private func save() async {
        guard isValid else { return }
        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }
        do {
            if resourceType == .link {
                _ = try await api.createResourceLink(
                    displayName: displayName.trimmingCharacters(in: .whitespaces),
                    url: linkURL.trimmingCharacters(in: .whitespaces),
                    folderId: folderId,
                    assignmentId: selectedAssignmentId,
                    assignedStudentIds: Array(selectedStudentIds)
                )
                onSaved()
            } else if let data = pendingFileData, let fileName = pendingFileName, let mimeType = pendingMimeType {
                if mimeType.hasPrefix("video/") {
                    await MainActor.run { errorMessage = "Video files are not supported; they are too large." }
                    return
                }
                let type: ResourceType = mimeType.hasPrefix("image/") ? .photo : .file
                let name = displayName.trimmingCharacters(in: .whitespaces).isEmpty ? fileName : displayName.trimmingCharacters(in: .whitespaces)
                _ = try await api.uploadResource(
                    displayName: name,
                    type: type,
                    folderId: folderId,
                    assignmentId: selectedAssignmentId,
                    assignedStudentIds: Array(selectedStudentIds),
                    fileName: fileName,
                    fileData: data,
                    mimeType: mimeType
                )
                onSaved()
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func handleFileResult(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try readFileData(from: url)
            let fileName = url.lastPathComponent
            let mimeType = getMimeType(for: url.pathExtension)
            if mimeType.hasPrefix("video/") {
                await MainActor.run { errorMessage = "Video files are not supported; they are too large." }
                return
            }
            await MainActor.run {
                pendingFileData = data
                pendingFileName = fileName
                pendingMimeType = mimeType
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func loadSelectedPhoto() async {
        guard let item = selectedPhotoItems.first else {
            await MainActor.run { pendingFileData = nil; pendingFileName = nil; pendingMimeType = nil }
            return
        }
        do {
            if let imageData = try await item.loadTransferable(type: ImageDataTransfer.self) {
                await MainActor.run {
                    pendingFileData = imageData.data
                    pendingFileName = "photo.jpg"
                    pendingMimeType = "image/jpeg"
                }
            } else {
                await MainActor.run { errorMessage = "Could not load photo. Try choosing from Files instead." }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func getMimeType(for ext: String) -> String {
        let map: [String: String] = [
            "pdf": "application/pdf", "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png", "gif": "image/gif",
            "mp4": "video/mp4", "mov": "video/quicktime", "txt": "text/plain"
        ]
        return map[ext.lowercased()] ?? "application/octet-stream"
    }
}

// MARK: - Edit Resource
private struct EditResourceSheet: View {
    let resource: Resource
    var folderId: String?
    let folders: [ResourceFolder]
    let availableStudents: [User]
    let onDismiss: () -> Void
    let onSaved: () -> Void
    @Binding var errorMessage: String?
    @State private var displayName = ""
    @State private var selectedFolderId: String?
    @State private var selectedAssignmentId: String?
    @State private var selectedStudentIds: Set<String> = []
    @State private var assignmentsLoaded: [Assignment] = []
    @State private var isSaving = false
    private let api = APIClient.shared

    var body: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("Name", text: $displayName)
                }
                Section("Folder") {
                    Picker("Folder", selection: $selectedFolderId) {
                        Text("Root").tag(nil as String?)
                        ForEach(folders) { f in
                            Text(folderPathString(folderId: f.id, in: folders))
                                .tag(f.id as String?)
                        }
                    }
                }
                Section("Link to assignment") {
                    Picker("Assignment", selection: $selectedAssignmentId) {
                        Text("None").tag(nil as String?)
                        ForEach(assignmentsLoaded, id: \.id) { a in
                            Text(a.title).tag(a.id as String?)
                        }
                    }
                }
                if !availableStudents.isEmpty {
                    Section("Assign to students") {
                        ForEach(availableStudents) { student in
                            Toggle(isOn: Binding(
                                get: { selectedStudentIds.contains(student.id) },
                                set: { isOn in
                                    if isOn {
                                        selectedStudentIds.insert(student.id)
                                    } else {
                                        selectedStudentIds.remove(student.id)
                                    }
                                }
                            )) {
                                Text(student.name ?? "Student")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Resource")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                displayName = resource.displayName
                selectedFolderId = resource.folderId
                selectedAssignmentId = resource.assignmentId
                selectedStudentIds = Set(resource.assignedStudentIds)
                Task { await loadAssignments() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDismiss) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func loadAssignments() async {
        do {
            assignmentsLoaded = try await api.fetchAssignments()
        } catch {}
    }

    private func save() async {
        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }
        do {
            _ = try await api.updateResource(
                id: resource.id,
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                folderId: selectedFolderId,
                assignmentId: selectedAssignmentId,
                assignedStudentIds: Array(selectedStudentIds)
            )
            onSaved()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: - Edit Folder
private struct EditFolderSheet: View {
    let folder: ResourceFolder
    let folders: [ResourceFolder]
    let onDismiss: () -> Void
    let onSaved: () -> Void
    @Binding var errorMessage: String?
    @State private var name = ""
    @State private var selectedParentFolderId: String?
    @State private var isSaving = false
    private let api = APIClient.shared

    /// Folders that can be chosen as parent (excludes self and descendants to avoid cycles).
    private var validParentOptions: [ResourceFolder] {
        let invalidIds = descendantIds(of: folder.id, in: folders)
        return folders.filter { !invalidIds.contains($0.id) }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("Folder name", text: $name)
                }
                Section("Parent folder") {
                    Picker("Location", selection: $selectedParentFolderId) {
                        Text("Root").tag(nil as String?)
                        ForEach(validParentOptions) { f in
                            Text(folderPathString(folderId: f.id, in: folders))
                                .tag(f.id as String?)
                        }
                    }
                }
            }
            .navigationTitle("Edit Folder")
            .onAppear {
                name = folder.name
                selectedParentFolderId = folder.parentFolderId
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDismiss) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }
        do {
            _ = try await api.updateResourceFolder(id: folder.id, name: name.trimmingCharacters(in: .whitespaces), parentFolderId: selectedParentFolderId)
            onSaved()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

