import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationManager = NotificationManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                if notificationManager.notifications.isEmpty {
                    ContentUnavailableView {
                        Label("All caught up", systemImage: "bell.slash")
                    } description: {
                        Text("You don't have any notifications right now.")
                    }
                } else {
                    ForEach(notificationManager.notifications) { notification in
                        NotificationRow(notification: notification)
                            .onTapGesture {
                                Task { await notificationManager.markAsRead(notification) }
                            }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .refreshable {
                await notificationManager.fetchNotifications()
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
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(iconColor))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.subheadline.bold())
                    Spacer()
                    if !notification.is_read {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(notification.body)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(AppFormatter.formatDate(notification.created_at))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
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
