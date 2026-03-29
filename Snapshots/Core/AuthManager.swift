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
            // Drive all auth state from the single authoritative stream.
            // authStateChanges always emits .initialSession first, which
            // replaces the separate supabase.auth.session call and closes
            // the race window where a magic-link event could fire between
            // the initial check completing and the loop starting.
            for await state in supabase.auth.authStateChanges {
                switch state.event {
                case .initialSession:
                    if let session = state.session {
                        self.isAuthenticated = true
                        self.checkProfileCompletion(session)
                        await SnapshotsAccessManager.shared.refreshEntitlementsForCurrentUser()
                    } else {
                        self.isAuthenticated = false
                        self.isProfileComplete = false
                        SnapshotsAccessManager.shared.clearEntitlementsForSignedOutUser()
                    }
                    self.isCheckingSession = false
                case .signedIn, .tokenRefreshed:
                    if let session = state.session {
                        self.isAuthenticated = true
                        self.checkProfileCompletion(session)
                        await SnapshotsAccessManager.shared.refreshEntitlementsForCurrentUser()
                    }
                case .signedOut:
                    self.isAuthenticated = false
                    self.isProfileComplete = false
                    SnapshotsAccessManager.shared.clearEntitlementsForSignedOutUser()
                default:
                    break
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
