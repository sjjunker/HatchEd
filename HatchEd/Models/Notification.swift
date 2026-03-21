//
//  Notification.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/8/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import Foundation

struct Notification: Identifiable, Codable, Equatable {
    let id: String
    let title: String?
    let body: String?
    let type: String? // e.g. "helpRequest" for urgent help requests
    let createdAt: Date?
    let deletedAt: Date?
    let userId: String?
    let read: Bool?
}
