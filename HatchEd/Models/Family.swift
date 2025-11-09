//
//  Family.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/3/25.
//
import Foundation

struct Family: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var joinCode: String?
    var members: [String]
    var createdAt: Date?
    var updatedAt: Date?
}

