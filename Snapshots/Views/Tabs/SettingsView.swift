import SwiftUI
import Supabase

struct SettingsView: View {
    @State private var isSigningOut = false
    @State private var showingSignOutAlert = false
    @State private var userName: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Section
                Section {
                    NavigationLink(destination: EditProfileView()) {
                        HStack(spacing: 14) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.gradient)
                                    .frame(width: 56, height: 56)
                                
                                Text(userName.prefix(1).uppercased())
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Signed In")
                                    .font(.headline)
                                Text(userName.isEmpty ? "Loading..." : userName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                }
                
                // MARK: - App Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    
                    HStack {
                        Label("Build", systemImage: "hammer")
                        Spacer()
                        Text("2026.3")
                            .foregroundColor(.secondary)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                } header: {
                    Text("App")
                }
                
                // MARK: - Account Actions
                Section {
                    Button(role: .destructive, action: { showingSignOutAlert = true }) {
                        HStack {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                            if isSigningOut {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSigningOut)
                } header: {
                    Text("Account")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive, action: signOut)
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .onAppear {
                fetchEmail()
            }
        }
    }
    
    private func fetchEmail() {
        Task {
            if let user = try? await supabase.auth.session.user {
                await MainActor.run {
                    if case let .string(name) = user.userMetadata["full_name"], !name.isEmpty {
                        self.userName = name
                    } else if let email = user.email {
                        self.userName = email.components(separatedBy: "@").first ?? email
                    }
                }
            }
        }
    }
    
    private func signOut() {
        isSigningOut = true
        Task {
            do {
                try await supabase.auth.signOut()
            } catch {
                print("Error signing out: \(error.localizedDescription)")
            }
            await MainActor.run {
                isSigningOut = false
            }
        }
    }
}

#Preview {
    SettingsView()
}
