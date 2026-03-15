import SwiftUI

enum UITestScenario: String {
    case login
    case checkInbox
    case completeProfile
    case feedback
    case settings

    static var current: UITestScenario? {
        guard let rawValue = ProcessInfo.processInfo.environment["SNAPSHOTS_UI_TEST_SCENARIO"] else {
            return nil
        }
        return UITestScenario(rawValue: rawValue)
    }
}

struct UITestScenarioView: View {
    @State private var authManager = AuthManager(
        isAuthenticated: true,
        isCheckingSession: false,
        isProfileComplete: false
    )

    private let scenario: UITestScenario

    init?(current: UITestScenario? = UITestScenario.current) {
        guard let current else { return nil }
        self.scenario = current
    }

    var body: some View {
        switch scenario {
        case .login:
            LoginView()
        case .checkInbox:
            NavigationStack {
                CheckInboxView(email: "tester@example.com", shouldCreateUser: false)
            }
        case .completeProfile:
            CompleteProfileView()
                .environment(authManager)
        case .feedback:
            FeedbackSheet(userName: "Jordan", personalTier: "free")
                .environment(SnapshotsAccessManager.shared)
        case .settings:
            SettingsView()
                .environment(SnapshotsAccessManager.shared)
        }
    }
}
