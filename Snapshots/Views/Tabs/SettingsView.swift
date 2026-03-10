import SwiftUI
import Supabase

struct SettingsView: View {
    @State private var isSigningOut = false
    @State private var showingSignOutAlert = false
    @State private var userName: String = ""
    @State private var showingPaywall = false
    @Environment(SnapshotsAccessManager.self) private var accessManager
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Section
                Section {
                    NavigationLink(destination: EditProfileView()) {
                        HStack(spacing: 14) {
                            // Avatar / Company Logo
                            if let logoUrlStr = accessManager.profile?.company_logo_url,
                               let logoUrl = URL(string: logoUrlStr) {
                                AsyncImage(url: logoUrl) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable()
                                            .scaledToFill()
                                            .frame(width: 56, height: 56)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    case .empty:
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.secondary.opacity(0.15))
                                            .frame(width: 56, height: 56)
                                            .overlay(ProgressView().scaleEffect(0.7))
                                    default:
                                        // Failure — fall back to letter avatar
                                        ZStack {
                                            Circle()
                                                .fill(Color.accentColor.gradient)
                                                .frame(width: 56, height: 56)
                                            Text(userName.prefix(1).uppercased())
                                                .font(.system(.title2, design: .rounded, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .id(logoUrlStr)
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor.gradient)
                                        .frame(width: 56, height: 56)
                                    Text(userName.prefix(1).uppercased())
                                        .font(.system(.title2, design: .rounded, weight: .bold))
                                        .foregroundColor(.white)
                                }
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
                
                // MARK: - Subscription Section
                Section {
                    Button {
                        showingPaywall = true
                    } label: {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(accessManager.isPro ? Color.accentColor.gradient : Color.secondary.opacity(0.15).gradient)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "star.fill")
                                    .font(.subheadline)
                                    .foregroundColor(accessManager.isPro ? .white : .secondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Snapshots Plan")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text(accessManager.isEnterprise ? "Enterprise" : accessManager.isPro ? "Professional" : "Standard")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if accessManager.isPro {
                                PlanBadge()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.bold())
                                    .foregroundColor(.secondary.opacity(0.5))
                            } else {
                                Text("Upgrade")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.accentColor))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                } header: {
                    Text("Plan")
                } footer: {
                    if accessManager.isPro {
                        Text("You have unlimited properties and team collaboration.")
                    } else {
                        Text("Manage 1 property for free. Upgrade for unlimited properties and team collaboration.")
                    }
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
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingPaywall) {
                PremiumPaywallView()
            }
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
                // Unregister device token for push notifications before sign out
                await NotificationManager.shared.unregisterDeviceToken()
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
