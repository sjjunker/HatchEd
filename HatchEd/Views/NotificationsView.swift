//
//  NotificationsView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct NotificationsView: View {
    let notifications: [Notification]
    let onSelect: (Notification) -> Void

    private let cardWidth: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.orange)
                Text("Notifications")
                    .font(.headline)
                Spacer()
            }

            if notifications.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        VStack(spacing: 8) {
                            Text("No new notifications")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("You're all caught up! We'll let you know when there's something to review.")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    )
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(notifications) { notification in
                            Button {
                                onSelect(notification)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(notification.title ?? "Untitled")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)

                                    Text(previewBody(for: notification))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)

                                    if let createdAt = notification.createdAt {
                                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .frame(width: cardWidth, alignment: .leading)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }

    private func previewBody(for notification: Notification) -> String {
        let bodyText = notification.body ?? ""
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 {
            return trimmed
        }
        let prefix = trimmed.prefix(77)
        return "\(prefix)…"
    }
}

#Preview {
    let sample = Notification(id: "1", title: "New Assignment", body: "Don't forget to review the latest assignment for math. It includes new problems to solve.", createdAt: Date(), deletedAt: nil, userId: nil, read: false)
    NotificationsView(notifications: [sample]) { _ in }
}

