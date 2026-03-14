import SwiftUI
import Supabase

struct CheckInboxView: View {
    let email: String
    let shouldCreateUser: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isRetrying = false
    @State private var retryErrorMessage: String?
    @State private var retrySuccessMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("✉️")
                .font(.system(size: 72))
                .padding(.bottom, 24)
                .padding(.top, 40)
            
            Text("auth.check_inbox.title")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 12)
            
            Text(String(format: NSLocalizedString("auth.check_inbox.message", comment: ""), email))
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
                .accessibilityIdentifier("check_inbox.message")

            VStack(alignment: .leading, spacing: 10) {
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

                HStack(spacing: 16) {
                    Button(action: resendMagicLink) {
                        HStack(spacing: 6) {
                            if isRetrying {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Try again")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .disabled(isRetrying)
                    .accessibilityIdentifier("check_inbox.retry")

                    Button("Try another email") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .disabled(isRetrying)
                    .accessibilityIdentifier("check_inbox.try_another")
                }
                .font(.footnote)
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Hide the back button to make it feel like a completed step
        .navigationBarBackButtonHidden(true)
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
                    retrySuccessMessage = "We sent a new magic link."
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
