import SwiftUI

struct NotificationBellView: View {
    @State private var showingNotifications = false
    @State private var notificationManager = NotificationManager.shared
    
    var body: some View {
        Button(action: { showingNotifications = true }) {
            Image(systemName: notificationManager.unreadCount > 0 ? "bell.badge" : "bell")
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
    }
}
