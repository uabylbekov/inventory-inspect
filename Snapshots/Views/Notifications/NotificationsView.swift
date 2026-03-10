import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationManager = NotificationManager.shared
    
    var body: some View {
        NavigationStack {
            Group {
                if notificationManager.notifications.isEmpty {
                    ScrollView {
                        ContentUnavailableView(
                            "notifications.empty.title",
                            systemImage: "bell.slash",
                            description: Text("notifications.empty.description")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 96)
                    }
                    .refreshable {
                        await notificationManager.fetchNotifications()
                    }
                } else {
                    List {
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
                    .refreshable {
                        await notificationManager.fetchNotifications()
                    }
                }
            }
            .navigationTitle("notifications.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if notificationManager.unreadCount > 0 {
                        Button("notifications.mark_all_read") {
                            Task { await notificationManager.markAllAsRead() }
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
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.gradient)
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(notification.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Text(AppFormatter.formatDate(notification.created_at))
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }

            Spacer()

            if !notification.is_read {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var iconName: String {
        switch notification.type {
        case "invitation": return "person.badge.plus"
        case "inspection_started": return "play.fill"
        case "inspection_completed": return "checkmark.circle.fill"
        default: return "bell.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.type {
        case "invitation": return .blue
        case "inspection_started": return .green
        case "inspection_completed": return .purple
        default: return .gray
        }
    }
}
