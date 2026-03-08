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
            VStack(alignment: .leading, spacing: 0) {
                Text("📸")
                    .font(.system(size: 56))
                    .padding(.bottom, 24)
                    .padding(.top, 40)
                
                Text("Sign in to\nSnapshots")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 12)
                
                Text("Enter your email address to receive a magic link. No passwords required.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
                
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isEmailFocused)
                    .disabled(isLoading)
                    .padding()
                    .background(Color(UIColor.secondarySystemFill))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(showValidationError ? Color.red.opacity(0.8) : Color.clear, lineWidth: 1)
                    )
                    .onChange(of: email) {
                        showValidationError = false
                        if errorMessage != nil { errorMessage = nil }
                    }
                    .onChange(of: isEmailFocused) {
                        // When the user stops typing and leaves the field
                        if !isEmailFocused && !email.isEmpty && !isEmailValid {
                            showValidationError = true
                        }
                    }
                    .onSubmit {
                        // Trigger validation if they press "Done" or "return" on the keyboard
                        if !email.isEmpty && !isEmailValid {
                            showValidationError = true
                        }
                    }
                    .padding(.bottom, 8)
                
                // Messages Fixed Height Area
                VStack(alignment: .leading) {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .transition(.opacity)
                    }
                }
                .frame(height: 20)
                .animation(.easeInOut, value: errorMessage)
                
                Spacer()
                
                Button(action: signIn) {
                    if isLoading {
                        ProgressView()
                            .padding(.trailing, 4)
                    }
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isEmailValid || isLoading)
                .animation(.easeInOut(duration: 0.2), value: isEmailValid)
            }
            .padding(32)
            // Background allows native iOS Light/Dark mode colors
            .background(Color(UIColor.systemBackground))
            .navigationDestination(isPresented: $isNavigatingToInbox) {
                CheckInboxView(email: email)
            }
            .alert("Account Not Found", isPresented: $showCreateAccountPrompt) {
                Button("Cancel", role: .cancel) { }
                Button("Create Account") {
                    createAccountAndSignIn()
                }
            } message: {
                Text("An account with this email does not exist. Would you like to create one?")
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
