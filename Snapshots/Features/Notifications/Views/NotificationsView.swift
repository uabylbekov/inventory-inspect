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
                                Task { await notificationManager.open(notification: notification) }
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
            .platformInlineNavigationTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if !notificationManager.notifications.isEmpty {
                        Button("notifications.clear_all", role: .destructive) {
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(notification.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    if !notification.is_read {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(notification.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(AppFormatter.formatDate(notification.created_at))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dimensions[.leading]
        }
    }

    private var iconName: String {
        let type = notification.type.lowercased()

        if type.contains("invite") || type.contains("member") || type.contains("team") {
            return "person.crop.badge.plus"
        }
        if type.contains("inspection") || type.contains("join") {
            return "checklist"
        }
        if type.contains("report") || type.contains("complete") {
            return "doc.text"
        }
        return "bell.badge"
    }

    private var iconColor: Color {
        let type = notification.type.lowercased()

        if type.contains("invite") || type.contains("member") || type.contains("team") {
            return .blue
        }
        if type.contains("inspection") || type.contains("join") {
            return .orange
        }
        if type.contains("report") || type.contains("complete") {
            return .green
        }
        return .secondary
    }
}
