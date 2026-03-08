import SwiftUI

struct NotificationBellView: View {
    @State private var showingNotifications = false
    @State private var notificationManager = NotificationManager.shared
    
    var body: some View {
        Button(action: { showingNotifications = true }) {
            ZStack {
                Image(systemName: "bell")
                    .symbolRenderingMode(.hierarchical)
                
                if notificationManager.unreadCount > 0 {
                    Text("\(notificationManager.unreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(.red))
                        .offset(x: 10, y: -8)
                }
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
    }
}
