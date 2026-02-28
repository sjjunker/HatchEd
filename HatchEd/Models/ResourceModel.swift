//
//  ResourceModel.swift
//  HatchEd
//

import Foundation

struct ResourceFolder: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var parentFolderId: String?
    var pendingDeletionAt: Date?
    var scheduledDeletionAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
}

enum ResourceType: String, Codable, CaseIterable {
    case file
    case link
    case photo

    var displayName: String {
        switch self {
        case .file: return "File"
        case .link: return "Link"
        case .photo: return "Photo"
        }
    }

    var systemImage: String {
        switch self {
        case .file: return "doc.fill"
        case .link: return "link"
        case .photo: return "photo.fill"
        }
    }
}

struct Resource: Identifiable, Codable, Equatable {
    let id: String
    var folderId: String?
    var displayName: String
    var type: ResourceType
    var fileUrl: String?
    var url: String?
    var mimeType: String?
    var fileSize: Int64?
    var assignmentId: String?
    var assignedStudentIds: [String]
    var createdAt: Date?
    var updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, folderId, displayName, type, fileUrl, url, mimeType, fileSize, assignmentId, assignedStudentIds, createdAt, updatedAt
    }

    init(id: String, folderId: String? = nil, displayName: String, type: ResourceType, fileUrl: String? = nil, url: String? = nil, mimeType: String? = nil, fileSize: Int64? = nil, assignmentId: String? = nil, assignedStudentIds: [String] = [], createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.folderId = folderId
        self.displayName = displayName
        self.type = type
        self.fileUrl = fileUrl
        self.url = url
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.assignmentId = assignmentId
        self.assignedStudentIds = assignedStudentIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        folderId = try container.decodeIfPresent(String.self, forKey: .folderId)
        displayName = try container.decode(String.self, forKey: .displayName)
        type = try container.decode(ResourceType.self, forKey: .type)
        fileUrl = try container.decodeIfPresent(String.self, forKey: .fileUrl)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
        assignmentId = try container.decodeIfPresent(String.self, forKey: .assignmentId)
        assignedStudentIds = try container.decodeIfPresent([String].self, forKey: .assignedStudentIds) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    /// URL to open: either the external link or the server file URL (client must prepend base URL for fileUrl).
    var openableURL: String? {
        if type == .link, let u = url, !u.isEmpty { return u }
        if let fu = fileUrl, !fu.isEmpty { return fu }
        return nil
    }
}
