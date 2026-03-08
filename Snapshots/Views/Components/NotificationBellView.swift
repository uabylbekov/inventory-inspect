import SwiftUI

struct NotificationBellView: View {
    @State private var showingNotifications = false
    @State private var notificationManager = NotificationManager.shared
    
    var body: some View {
        Button(action: { showingNotifications = true }) {
            ZStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                
                if notificationManager.unreadCount > 0 {
                    Text("\(notificationManager.unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(.red))
                        .offset(x: 10, y: -10)
                }
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
    }
}
