import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationManager = NotificationManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                if notificationManager.notifications.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "notifications.empty.title",
                            systemImage: "bell.slash",
                            description: Text("notifications.empty.description")
                        )
                    }
                } else {
                    ForEach(notificationManager.notifications) { notification in
                        NotificationRow(notification: notification)
                            .onTapGesture {
                                Task { await notificationManager.markAsRead(notification) }
                            }
                    }
                    .onDelete { offsets in
                        notificationManager.deleteNotifications(at: offsets)
                    }
                }
            }
            .refreshable {
                await notificationManager.fetchNotifications()
            }
            .navigationTitle("notifications.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if !notificationManager.notifications.isEmpty {
                        Button("Clear all", role: .destructive) {
                            Task { await notificationManager.clearAllNotifications() }
                        }
                    }
                }
            }
        }
        .task {
            await notificationManager.fetchNotifications()
        }
    }
}

struct NotificationRow: View {
    let notification: NotificationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(notification.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                if !notification.is_read {
                    Spacer()
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                }
            }

            Text(notification.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Text(AppFormatter.formatDate(notification.created_at))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
