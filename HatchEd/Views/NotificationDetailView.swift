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
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.hatchEdWarning)
                        Text(notification.title ?? "Untitled Notification")
                            .font(.title2.bold())
                            .foregroundColor(.hatchEdText)
                    }

                    if let createdAt = notification.createdAt {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundColor(.hatchEdAccent)
                            Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.hatchEdSecondaryText)
                        }
                    }

                    Divider()
                        .background(Color.hatchEdSecondaryBackground)

                    Text(notification.body ?? "")
                        .font(.body)
                        .foregroundColor(.hatchEdText)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.hatchEdCardBackground)
                        )

                    Spacer(minLength: 24)

                    Button(role: .destructive) {
                        onDelete(notification)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Delete Notification")
                            Spacer()
                        }
                        .foregroundColor(.hatchEdWhite)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.hatchEdCoralAccent)
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
