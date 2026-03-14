import SwiftUI
import Supabase

struct LoginView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isNavigatingToInbox = false
    @State private var showValidationError = false
    @State private var showCreateAccountPrompt = false
    @State private var shouldCreateUserOnNextAttempt = false
    @FocusState private var isEmailFocused: Bool

    private var canAttemptSignIn: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var isEmailValid: Bool {
        isValidEmail(email)
    }
    
    var body: some View {
        NavigationStack {
            loginContent
                .navigationDestination(isPresented: $isNavigatingToInbox) {
                    CheckInboxView(
                        email: email,
                        shouldCreateUser: shouldCreateUserOnNextAttempt
                    )
                }
                .alert("auth.login.account_not_found_title", isPresented: $showCreateAccountPrompt) {
                    Button("common.cancel", role: .cancel) { }
                    Button("auth.login.create_account") {
                        createAccountAndSignIn()
                    }
                } message: {
                    Text("auth.login.account_not_found_message")
                }
        }
    }

    @ViewBuilder
    private var loginContent: some View {
        compactLoginLayout
    }

    private var compactLoginLayout: some View {
        List {
            Section {
                loginHeader
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
            }

            Section("auth.login.email_section") {
                emailField

                if showValidationError {
                    validationMessage
                }
            }

            Section {
                continueButton(useProminentStyle: false)
            } footer: {
                errorFooter
            }
        }
        .applyLoginListStyle()
    }

    private var loginHeader: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)

            VStack(spacing: 8) {
                Text("auth.login.app_name")
                    .font(.title.bold())
                Text("auth.login.subtitle")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emailField: some View {
        TextField("auth.common.email", text: $email)
            .platformEmailTextInput()
            .autocorrectionDisabled()
            .focused($isEmailFocused)
            .disabled(isLoading)
            .accessibilityIdentifier("login.email")
            .onChange(of: email) { _, newValue in
                if showValidationError {
                    showValidationError = !isValidEmail(newValue)
                }
                if errorMessage != nil {
                    errorMessage = nil
                }
            }
    }

    private var validationMessage: some View {
        Label("auth.login.invalid_email", systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundColor(.red)
            .accessibilityIdentifier("login.invalid_email")
    }

    @ViewBuilder
    private var errorFooter: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("login.error")
        }
    }

    private func continueButton(useProminentStyle: Bool) -> some View {
        Button(action: signIn) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("auth.common.continue")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: useProminentStyle ? nil : .infinity)
        }
        .disabled(!canAttemptSignIn || isLoading)
        .accessibilityIdentifier("login.continue")
        .applyContinueButtonStyle(useProminentStyle: useProminentStyle)
        .keyboardShortcut(.defaultAction)
        .applyCompactButtonRowStyle(isEnabled: canAttemptSignIn && !isLoading, useProminentStyle: useProminentStyle)
    }
    
    private func signIn() {
        guard isEmailValid else {
            showValidationError = true
            errorMessage = nil
            return
        }
        // Hide keyboard when submitting
        dismissKeyboard()
        
        showValidationError = false
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                shouldCreateUserOnNextAttempt = false
                try await supabase.auth.signInWithOTP(
                    email: email,
                    redirectTo: URL(string: "snapshots://login-callback"),
                    shouldCreateUser: false
                )
                // Trigger navigation
                isNavigatingToInbox = true
                isLoading = false
            } catch {
                let errorMsg = error.localizedDescription
                // Supabase API usually returns "Signups not allowed for this app" or similar if shouldCreateUser is false and user doesnt exist
                if errorMsg.contains("Signups not allowed") || errorMsg.contains("User not found") || errorMsg.lowercased().contains("not found") {
                    showCreateAccountPrompt = true
                    isLoading = false
                } else {
                    withAnimation {
                        errorMessage = errorMsg
                    }
                    isLoading = false
                }
            }
        }
    }
    
    private func createAccountAndSignIn() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                shouldCreateUserOnNextAttempt = true
                try await supabase.auth.signInWithOTP(
                    email: email,
                    redirectTo: URL(string: "snapshots://login-callback"),
                    shouldCreateUser: true
                )
                isNavigatingToInbox = true
            } catch {
                withAnimation {
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }

    private func dismissKeyboard() {
        dismissPlatformKeyboard()
    }

    private func isValidEmail(_ value: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: value)
    }
}

private extension View {
    @ViewBuilder
    func applyLoginListStyle() -> some View {
#if os(iOS)
        self.listStyle(.insetGrouped)
#elseif os(macOS)
        self.listStyle(.inset(alternatesRowBackgrounds: false))
#else
        self.listStyle(.inset)
#endif
    }

    @ViewBuilder
    func applyCompactButtonRowStyle(isEnabled: Bool, useProminentStyle: Bool) -> some View {
#if os(macOS)
        self
#else
        if useProminentStyle {
            self
        } else {
            self
                .listRowBackground(isEnabled ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundColor(isEnabled ? .white : .secondary)
        }
#endif
    }

    @ViewBuilder
    func applyContinueButtonStyle(useProminentStyle: Bool) -> some View {
        if useProminentStyle {
#if os(macOS)
            self
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
#else
            self
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
#endif
        } else {
            self.controlSize(.regular)
        }
    }
}

#Preview {
    LoginView()
}
