import SwiftUI
import Supabase

@Observable @MainActor
final class AuthManager {
    var isAuthenticated = false
    var isCheckingSession = true
    var isProfileComplete = false

    init(skipBootstrap: Bool = false) {
        guard !skipBootstrap else {
            isCheckingSession = false
            return
        }

        Task {
            do {
                let session = try await supabase.auth.session
                self.isAuthenticated = true
                self.checkProfileCompletion(session)
                self.isCheckingSession = false
                await SnapshotsAccessManager.shared.refreshEntitlementsForCurrentUser()
            } catch {
                self.isAuthenticated = false
                self.isProfileComplete = false
                self.isCheckingSession = false
                SnapshotsAccessManager.shared.clearEntitlementsForSignedOutUser()
            }

            for await state in supabase.auth.authStateChanges {
                if let session = state.session {
                    self.isAuthenticated = true
                    self.checkProfileCompletion(session)
                } else {
                    self.isAuthenticated = false
                    self.isProfileComplete = false
                }
                if state.session != nil {
                    await SnapshotsAccessManager.shared.refreshEntitlementsForCurrentUser()
                } else {
                    SnapshotsAccessManager.shared.clearEntitlementsForSignedOutUser()
                }
            }
        }
    }

    convenience init(
        isAuthenticated: Bool,
        isCheckingSession: Bool,
        isProfileComplete: Bool
    ) {
        self.init(skipBootstrap: true)
        self.isAuthenticated = isAuthenticated
        self.isCheckingSession = isCheckingSession
        self.isProfileComplete = isProfileComplete
    }
    
    private func checkProfileCompletion(_ session: Session) {
        if case .string(let fullName) = session.user.userMetadata["full_name"], !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.isProfileComplete = true
        } else {
            self.isProfileComplete = false
        }
    }
}
