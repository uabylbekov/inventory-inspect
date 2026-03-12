import SwiftUI

struct RootView: View {
    @State private var authManager = AuthManager()
    
    var body: some View {
        Group {
            if authManager.isCheckingSession {
                loadingView
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

    @ViewBuilder
    private var loadingView: some View {
#if os(macOS)
        ZStack {
            Color.platformGroupedBackground
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.regular)
                Text("Snapshots")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .frame(width: 220, height: 120)
            .background(Color.platformSystemBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
#else
        VStack(spacing: 20) {
            Text("Snapshots")
                .font(.title2.bold())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.platformSystemBackground)
#endif
    }
}

#Preview {
    RootView()
}
