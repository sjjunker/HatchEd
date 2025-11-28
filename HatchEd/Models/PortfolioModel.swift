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

struct Portfolio: Identifiable, Codable, Equatable {
    let id: String
    var studentId: String
    var studentName: String
    var designPattern: PortfolioDesignPattern
    var studentWorkFileIds: [String]
    var studentRemarks: String?
    var instructorRemarks: String?
    var reportCardSnapshot: String? // JSON string of report card at time of creation
    var compiledContent: String // Content compiled by ChatGPT
    var snippet: String // Short preview snippet
    var createdAt: Date?
    var updatedAt: Date?
    
    init(id: String = UUID().uuidString, 
         studentId: String,
         studentName: String,
         designPattern: PortfolioDesignPattern,
         studentWorkFileIds: [String] = [],
         studentRemarks: String? = nil,
         instructorRemarks: String? = nil,
         reportCardSnapshot: String? = nil,
         compiledContent: String = "",
         snippet: String = "",
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
        self.compiledContent = compiledContent
        self.snippet = snippet
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct StudentWorkFile: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var fileName: String
    var fileUrl: String // URL to the file on server
    var fileType: String // e.g., "image/png", "application/pdf"
    var fileSize: Int64 // Size in bytes
    var studentId: String
    var uploadedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
    
    init(id: String = UUID().uuidString,
         fileName: String,
         fileUrl: String,
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

