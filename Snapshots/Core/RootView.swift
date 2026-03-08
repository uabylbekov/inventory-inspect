import SwiftUI

struct RootView: View {
    @State private var authManager = AuthManager()
    
    var body: some View {
        Group {
            if authManager.isCheckingSession {
                VStack(spacing: 20) {
                    Text("Snapshots")
                        .font(.title2.bold())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
                .transition(.opacity)
            } else if authManager.isAuthenticated {
                if authManager.isProfileComplete {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    CompleteProfileView()
                        .transition(.opacity)
                }
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.default, value: authManager.isCheckingSession)
        .animation(.default, value: authManager.isAuthenticated)
        .animation(.default, value: authManager.isProfileComplete)
        .environment(authManager)
        .task(id: authManager.isAuthenticated) {
            if authManager.isAuthenticated {
                await NotificationManager.shared.setupRealtime()
                await NotificationManager.shared.fetchNotifications()
                NotificationManager.shared.requestPermission()
            }
        }
    }
}

#Preview {
    RootView()
}