import SwiftUI
import Supabase

struct CheckInboxView: View {
    let email: String
    let shouldCreateUser: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isRetrying = false
    @State private var retryErrorMessage: String?
    @State private var retrySuccessMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                inboxHeader
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)

                messageCard

                actionStack

                statusBlock
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationBarBackButtonHidden(true)
    }

    private var inboxHeader: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)

            VStack(spacing: 8) {
                Text("auth.check_inbox.title")
                    .font(.title.bold())

                Text("auth.login.app_name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var messageCard: some View {
        Text(String(format: NSLocalizedString("auth.check_inbox.message", comment: ""), email))
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("check_inbox.message")
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            }
    }

    private var openMailButton: some View {
        Button {
            openMailApp()
        } label: {
            Text("auth.check_inbox.open_mail")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .disabled(isRetrying)
        .accessibilityIdentifier("check_inbox.open_mail")
    }

    private var resendEmailButton: some View {
        Button(action: resendMagicLink) {
            HStack(spacing: 8) {
                if isRetrying {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("auth.check_inbox.resend_email")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .disabled(isRetrying)
        .accessibilityIdentifier("check_inbox.retry")
    }

    private var tryAnotherEmailButton: some View {
        Button("auth.check_inbox.try_another") {
            dismiss()
        }
        .accessibilityIdentifier("check_inbox.try_another")
    }

    private var actionStack: some View {
        VStack(alignment: .leading, spacing: 12) {
            openMailButton
            resendEmailButton
            tryAnotherEmailButton
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var statusBlock: some View {
        if let retrySuccessMessage {
            Text(retrySuccessMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if let retryErrorMessage {
            Text(retryErrorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func openMailApp() {
#if os(iOS)
        if let inboxURL = URL(string: "message://") {
            openURL(inboxURL)
            return
        }
#endif
        if let composeURL = URL(string: "mailto:") {
            openURL(composeURL)
        }
    }

    private func resendMagicLink() {
        isRetrying = true
        retryErrorMessage = nil
        retrySuccessMessage = nil

        Task {
            do {
                try await supabase.auth.signInWithOTP(
                    email: email,
                    redirectTo: URL(string: "snapshots://login-callback"),
                    shouldCreateUser: shouldCreateUser
                )

                await MainActor.run {
                    retrySuccessMessage = String(localized: "auth.check_inbox.retry_success")
                    isRetrying = false
                }
            } catch {
                await MainActor.run {
                    retryErrorMessage = error.localizedDescription
                    isRetrying = false
                }
            }
        }
    }
}

#Preview {
    CheckInboxView(email: "test@example.com", shouldCreateUser: false)
}
