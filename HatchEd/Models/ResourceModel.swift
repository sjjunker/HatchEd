//
//  ResourceModel.swift
//  HatchEd
//

import Foundation

struct ResourceFolder: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var parentFolderId: String?
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
    var createdAt: Date?
    var updatedAt: Date?

    /// URL to open: either the external link or the server file URL (client must prepend base URL for fileUrl).
    var openableURL: String? {
        if type == .link, let u = url, !u.isEmpty { return u }
        if let fu = fileUrl, !fu.isEmpty { return fu }
        return nil
    }
}
