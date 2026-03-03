import SwiftUI
import Supabase

@Observable
final class AuthManager {
    var isAuthenticated = false
    
    init() {
        Task {
            for await state in supabase.auth.authStateChanges {
                await MainActor.run {
                    self.isAuthenticated = state.session != nil
                }
            }
        }
    }
}
