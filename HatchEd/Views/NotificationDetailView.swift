//
//  NotificationDetailView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//

import SwiftUI

struct NotificationDetailView: View {
    let notification: Notification
    let onDelete: (Notification) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(notification.title ?? "Untitled Notification")
                        .font(.title2.bold())

                    if let createdAt = notification.createdAt {
                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    Text(notification.body ?? "")
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer(minLength: 24)

                    Button(role: .destructive) {
                        onDelete(notification)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Notification")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let sample = Notification(id: "1", title: "Reminder", body: "Please review your student's latest assignment.", createdAt: Date(), deletedAt: nil, userId: nil, read: false)
    NotificationDetailView(notification: sample) { _ in }
}
