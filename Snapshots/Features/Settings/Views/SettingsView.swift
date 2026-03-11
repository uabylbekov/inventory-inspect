import SwiftUI
import Supabase

struct SettingsView: View {
    @State private var isSigningOut = false
    @State private var showingSignOutAlert = false
    @State private var showingFeedbackSheet = false
    @State private var showingEditProfile = false
    @State private var userName: String = ""
    @Environment(SnapshotsAccessManager.self) private var accessManager
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: { showingEditProfile = true }) {
                        HStack {
                            Text("profile.title")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(displayName)
                                Text(currentPlanName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Section {
                    SubscriptionPlanRow()
                } header: {
                    Text("settings.plan")
                } footer: {
                    if accessManager.isDirectSubscriber {
                        Text("settings.plan.footer.paid")
                    } else {
                        Text("settings.plan.footer.free")
                    }
                }
                
                Section {
                    Button {
                        showingFeedbackSheet = true
                    } label: {
                        Text("settings.feedback")
                    }
                } header: {
                    Text("settings.support")
                }

                Section {
                    NavigationLink {
                        SettingsAboutView(
                            version: appVersion,
                            build: buildNumber
                        )
                    } label: {
                        LabeledContent {
                            Text("\(String(localized: "settings.version")) \(appVersion) • \(String(localized: "settings.build")) \(buildNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("settings.about", systemImage: "info.circle")
                        }
                    }
                } header: {
                    Text("settings.app")
                }
                
                Section {
                    Button(role: .destructive, action: { showingSignOutAlert = true }) {
                        HStack {
                            Label("settings.sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                            if isSigningOut {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSigningOut)
                } header: {
                    Text("settings.account")
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.large)
            .alert("settings.sign_out_title", isPresented: $showingSignOutAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("settings.sign_out", role: .destructive, action: signOut)
            } message: {
                Text("settings.sign_out_message")
            }
            .sheet(isPresented: $showingFeedbackSheet) {
                FeedbackSheet(
                    userName: userName,
                    personalTier: accessManager.profile?.subscription_tier ?? accessManager.activeProductTier
                )
            }
            .navigationDestination(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .onAppear {
                fetchEmail()
            }
        }
    }

    private var displayName: String {
        userName.isEmpty ? String(localized: "settings.loading") : userName
    }

    private var currentPlanName: String {
        if accessManager.isDirectSubscriberEnterprise { return String(localized: "plan.enterprise") }
        if accessManager.isDirectSubscriber { return String(localized: "plan.professional") }
        return String(localized: "plan.standard")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2026.3"
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

private struct SettingsAboutView: View {
    let version: String
    let build: String

    var body: some View {
        List {
            Section {
                LabeledContent("settings.version", value: version)
                LabeledContent("settings.build", value: build)
            }
        }
        .navigationTitle("settings.about")
        .navigationBarTitleDisplayMode(.inline)
    }
}
