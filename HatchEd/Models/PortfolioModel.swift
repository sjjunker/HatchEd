//
//  PortfolioModel.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//

import Foundation

enum PortfolioDesignPattern: String, Codable, CaseIterable, Identifiable {
    case artistic = "Artistic"
    case scientific = "Scientific"
    case general = "General"
    case academic = "Academic"
    case creative = "Creative"
    
    var id: String { rawValue }
}

/// Reference to an image stored in the portfolioImages collection. No URL stored; load via GET /api/portfolios/images/:id.
struct PortfolioImage: Identifiable, Codable, Equatable {
    let id: String
    var description: String

    init(id: String = UUID().uuidString, description: String) {
        self.id = id
        self.description = description
    }
}

struct PortfolioSectionData: Codable, Equatable {
    var aboutMe: String?
    var achievementsAndAwards: String?
    var attendanceNotes: String?
    var extracurricularActivities: String?
    var serviceLog: String?
    
    init(aboutMe: String? = nil,
         achievementsAndAwards: String? = nil,
         attendanceNotes: String? = nil,
         extracurricularActivities: String? = nil,
         serviceLog: String? = nil) {
        self.aboutMe = aboutMe
        self.achievementsAndAwards = achievementsAndAwards
        self.attendanceNotes = attendanceNotes
        self.extracurricularActivities = extracurricularActivities
        self.serviceLog = serviceLog
    }
}

struct Portfolio: Identifiable, Codable, Equatable {
    let id: String
    var studentId: String
    var studentName: String
    var designPattern: PortfolioDesignPattern
    var studentWorkFileIds: [String]
    var studentRemarks: String?
    var instructorRemarks: String?
    var reportCardSnapshot: String? // JSON string of report card at time of creation
    var sectionData: PortfolioSectionData? // User-provided section data
    var compiledContent: String // Content compiled by ChatGPT
    var snippet: String // Short preview snippet
    var generatedImages: [PortfolioImage] // AI-generated images
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case studentId
        case studentName
        case designPattern
        case studentWorkFileIds
        case studentRemarks
        case instructorRemarks
        case reportCardSnapshot
        case sectionData
        case compiledContent
        case snippet
        case generatedImages
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        studentId = try container.decode(String.self, forKey: .studentId)
        studentName = try container.decode(String.self, forKey: .studentName)
        designPattern = try container.decode(PortfolioDesignPattern.self, forKey: .designPattern)
        studentWorkFileIds = try container.decodeIfPresent([String].self, forKey: .studentWorkFileIds) ?? []
        studentRemarks = try container.decodeIfPresent(String.self, forKey: .studentRemarks)
        instructorRemarks = try container.decodeIfPresent(String.self, forKey: .instructorRemarks)
        reportCardSnapshot = try container.decodeIfPresent(String.self, forKey: .reportCardSnapshot)
        sectionData = try container.decodeIfPresent(PortfolioSectionData.self, forKey: .sectionData)
        compiledContent = try container.decodeIfPresent(String.self, forKey: .compiledContent) ?? ""
        snippet = try container.decodeIfPresent(String.self, forKey: .snippet) ?? ""
        
        // Handle generatedImages with fallback for missing or invalid data
        if let images = try? container.decode([PortfolioImage].self, forKey: .generatedImages) {
            generatedImages = images
        } else {
            generatedImages = []
        }
        
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(studentId, forKey: .studentId)
        try container.encode(studentName, forKey: .studentName)
        try container.encode(designPattern, forKey: .designPattern)
        try container.encode(studentWorkFileIds, forKey: .studentWorkFileIds)
        try container.encodeIfPresent(studentRemarks, forKey: .studentRemarks)
        try container.encodeIfPresent(instructorRemarks, forKey: .instructorRemarks)
        try container.encodeIfPresent(reportCardSnapshot, forKey: .reportCardSnapshot)
        try container.encodeIfPresent(sectionData, forKey: .sectionData)
        try container.encode(compiledContent, forKey: .compiledContent)
        try container.encode(snippet, forKey: .snippet)
        try container.encode(generatedImages, forKey: .generatedImages)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
    
    init(id: String = UUID().uuidString, 
         studentId: String,
         studentName: String,
         designPattern: PortfolioDesignPattern,
         studentWorkFileIds: [String] = [],
         studentRemarks: String? = nil,
         instructorRemarks: String? = nil,
         reportCardSnapshot: String? = nil,
         sectionData: PortfolioSectionData? = nil,
         compiledContent: String = "",
         snippet: String = "",
         generatedImages: [PortfolioImage] = [],
         createdAt: Date? = nil,
         updatedAt: Date? = nil) {
        self.id = id
        self.studentId = studentId
        self.studentName = studentName
        self.designPattern = designPattern
        self.studentWorkFileIds = studentWorkFileIds
        self.studentRemarks = studentRemarks
        self.instructorRemarks = instructorRemarks
        self.reportCardSnapshot = reportCardSnapshot
        self.sectionData = sectionData
        self.compiledContent = compiledContent
        self.snippet = snippet
        self.generatedImages = generatedImages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct StudentWorkFile: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var fileName: String
    /// Optional; files are stored in DB and loaded via GET /api/portfolios/images/:id when needed.
    var fileUrl: String?
    var fileType: String // e.g., "image/png", "application/pdf"
    var fileSize: Int64 // Size in bytes
    var studentId: String
    var uploadedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
    
    init(id: String = UUID().uuidString,
         fileName: String,
         fileUrl: String? = nil,
         fileType: String,
         fileSize: Int64,
         studentId: String,
         uploadedAt: Date? = nil,
         createdAt: Date? = nil,
         updatedAt: Date? = nil) {
        self.id = id
        self.fileName = fileName
        self.fileUrl = fileUrl
        self.fileType = fileType
        self.fileSize = fileSize
        self.studentId = studentId
        self.uploadedAt = uploadedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

