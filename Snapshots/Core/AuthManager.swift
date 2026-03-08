import SwiftUI
import Supabase

@Observable
final class AuthManager {
    var isAuthenticated = false
    var isCheckingSession = true
    var isProfileComplete = false
    
    init() {
        Task {
            do {
                let session = try await supabase.auth.session
                await MainActor.run {
                    self.isAuthenticated = true
                    self.checkProfileCompletion(session)
                    self.isCheckingSession = false
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticated = false
                    self.isProfileComplete = false
                    self.isCheckingSession = false
                }
            }
            
            for await state in supabase.auth.authStateChanges {
                await MainActor.run {
                    if let session = state.session {
                        self.isAuthenticated = true
                        self.checkProfileCompletion(session)
                    } else {
                        self.isAuthenticated = false
                        self.isProfileComplete = false
                    }
                }
            }
        }
    }
    
    private func checkProfileCompletion(_ session: Session) {
        if case .string(let fullName) = session.user.userMetadata["full_name"], !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.isProfileComplete = true
        } else {
            self.isProfileComplete = false
        }
    }
}
