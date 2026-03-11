import SwiftUI
import Supabase

struct LoginView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isNavigatingToInbox = false
    @State private var showValidationError = false
    @State private var showCreateAccountPrompt = false
    @FocusState private var isEmailFocused: Bool
    
    private var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .center, spacing: 16) {
                        Text("📸")
                            .font(.system(size: 80))
                        
                        VStack(spacing: 8) {
                            Text("auth.login.app_name")
                                .font(.largeTitle.bold())
                            Text("auth.login.subtitle")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                }
                
                Section("auth.login.email_section") {
                    TextField("auth.common.email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($isEmailFocused)
                        .disabled(isLoading)
                    
                    if showValidationError {
                        Label("auth.login.invalid_email", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: signIn) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("auth.common.continue")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!isEmailValid || isLoading)
                    .listRowBackground(isEmailValid && !isLoading ? Color.accentColor : Color.secondary.opacity(0.1))
                    .foregroundColor(isEmailValid && !isLoading ? .white : .secondary)
                } footer: {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationDestination(isPresented: $isNavigatingToInbox) {
                CheckInboxView(email: email)
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
    
    private func signIn() {
        guard isEmailValid else { return }
        // Hide keyboard when submitting
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
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
}

#Preview {
    LoginView()
}
