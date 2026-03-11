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
            } else if authManager.isAuthenticated {
                if authManager.isProfileComplete {
                    MainTabView()
                } else {
                    CompleteProfileView()
                }
            } else {
                LoginView()
            }
        }
        .environment(authManager)
        .task(id: authManager.isAuthenticated) {
            if authManager.isAuthenticated {
                await NotificationManager.shared.bootstrapForAuthenticatedUser()
            } else {
                await NotificationManager.shared.resetForSignedOutUser()
            }
        }
    }
}

#Preview {
    RootView()
}
