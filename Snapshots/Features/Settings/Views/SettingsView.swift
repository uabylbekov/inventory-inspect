import SwiftUI
import Supabase

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var isSigningOut = false
    @State private var showingSignOutAlert = false
    @State private var showingFeedbackSheet = false
    @State private var showingEditProfile = false
    @State private var legalAlertMessage: String?
    @State private var userName: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: { showingEditProfile = true }) {
                        SettingsProfileRow(displayName: displayName)
                            .accessibilityIdentifier("settings.edit_profile")
                    }
                    .buttonStyle(.plain)
                }
                
                Section {
                    SubscriptionPlanRow()
                } header: {
                    Text("settings.plan")
                } footer: {
                    SettingsPlanFooter()
                }

                SettingsUsageSection()
                
                Section {
                    Button {
                        showingFeedbackSheet = true
                    } label: {
                        Label("settings.feedback", systemImage: "bubble.left.and.bubble.right")
                            .accessibilityIdentifier("settings.feedback")
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
                    Button {
                        openLegalURL(EnvConfig.termsOfServiceURL)
                    } label: {
                        Label("paywall.terms", systemImage: "doc.text")
                    }
                    Button {
                        openLegalURL(EnvConfig.privacyPolicyURL)
                    } label: {
                        Label("paywall.privacy", systemImage: "hand.raised")
                    }
                } header: {
                    Text("settings.app")
                }
                
                Section {
                    Button(role: .destructive, action: { showingSignOutAlert = true }) {
                        HStack {
                            Label("settings.sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                                .accessibilityIdentifier("settings.sign_out")
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
            .applySettingsListStyle()
            .navigationTitle("settings.title")
            .platformLargeNavigationTitleDisplayMode()
            .alert("settings.sign_out_title", isPresented: $showingSignOutAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("settings.sign_out", role: .destructive, action: signOut)
            } message: {
                Text("settings.sign_out_message")
            }
            .alert("paywall.legal", isPresented: Binding(
                get: { legalAlertMessage != nil },
                set: { if !$0 { legalAlertMessage = nil } }
            )) {
                Button("common.ok", role: .cancel) { legalAlertMessage = nil }
            } message: {
                Text(legalAlertMessage ?? "")
            }
            .sheet(isPresented: $showingFeedbackSheet) {
                FeedbackSheetContainer(userName: userName)
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

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2026.3"
    }

    private func openLegalURL(_ url: URL?) {
        guard let url else {
            legalAlertMessage = String(localized: "paywall.legal_missing")
            return
        }
        openURL(url)
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

private struct SettingsProfileRow: View {
    @Environment(SnapshotsAccessManager.self) private var accessManager

    let displayName: String

    var body: some View {
        HStack {
            Label("profile.title", systemImage: "person.crop.circle")
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(displayName)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(currentPlanName)
                    if let cadenceLabel {
                        Text(cadenceLabel)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    private var currentPlanName: String {
        if accessManager.hasBusinessAccess { return String(localized: "plan.business") }
        if accessManager.hasDirectPaidAccess { return String(localized: "plan.professional") }
        return String(localized: "plan.standard")
    }

    private var cadenceLabel: String? {
        accessManager.activeBillingCadenceLabel
    }
}

private struct SettingsPlanFooter: View {
    @Environment(SnapshotsAccessManager.self) private var accessManager

    var body: some View {
        if accessManager.hasDirectPaidAccess {
            Text("settings.plan.footer.paid")
        } else {
            Text("settings.plan.footer.free")
        }
    }
}

private struct SettingsUsageSection: View {
    @Environment(SnapshotsAccessManager.self) private var accessManager

    var body: some View {
        Section {
            LabeledContent("settings.usage.photos") {
                Text("\(accessManager.photoUsageCount) / \(accessManager.directTierLimits.photoLimit)")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("settings.usage.properties") {
                Text(String(accessManager.directTierLimits.propertyLimit))
                    .foregroundStyle(.secondary)
            }
            LabeledContent("settings.usage.team") {
                Text(teamLimitText)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("settings.usage")
        } footer: {
            Text("settings.usage.footer")
        }
    }

    private var teamLimitText: String {
        accessManager.directTierLimits.teamLimit == 0
            ? String(localized: "settings.usage.team_none")
            : String(accessManager.directTierLimits.teamLimit)
    }
}

private struct FeedbackSheetContainer: View {
    @Environment(SnapshotsAccessManager.self) private var accessManager

    let userName: String

    var body: some View {
        FeedbackSheet(
            userName: userName,
            personalTier: effectivePersonalTier
        )
    }

    private var effectivePersonalTier: String {
        if accessManager.hasBusinessAccess { return "business" }
        if accessManager.hasDirectPaidAccess { return "pro" }
        return accessManager.profile?.effectiveSubscriptionTier ?? "free"
    }
}

private struct SettingsAboutView: View {
    let version: String
    let build: String

    var body: some View {
        List {
            Section {
                LabeledContent {
                    Text(version)
                } label: {
                    Label("settings.version", systemImage: "number")
                }
                LabeledContent {
                    Text(build)
                } label: {
                    Label("settings.build", systemImage: "hammer")
                }
            }
        }
        .navigationTitle("settings.about")
        .platformInlineNavigationTitleDisplayMode()
    }
}

private extension View {
    @ViewBuilder
    func applySettingsListStyle() -> some View {
#if os(macOS)
        self.listStyle(.inset(alternatesRowBackgrounds: false))
#else
        self
#endif
    }
}
