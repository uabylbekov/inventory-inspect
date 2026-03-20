import SwiftUI

struct NotificationBellView: View {
    @State private var showingNotifications = false
    @State private var notificationManager = NotificationManager.shared
    
    var body: some View {
        Button(action: { showingNotifications = true }) {
            if notificationManager.unreadCount > 0 {
                Image(systemName: "bell.badge")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.red, Color.primary)
            } else {
                Image(systemName: "bell")
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
    }
}
