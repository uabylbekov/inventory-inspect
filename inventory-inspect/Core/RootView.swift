import SwiftUI

struct RootView: View {
    @State private var authManager = AuthManager()
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environment(authManager)
    }
}

#Preview {
    RootView()
}