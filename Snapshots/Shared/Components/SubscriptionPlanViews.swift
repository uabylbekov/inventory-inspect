import SwiftUI
import StoreKit

struct SubscriptionPlanRow: View {
    @Environment(SnapshotsAccessManager.self) private var accessManager

    var body: some View {
        NavigationLink {
            SubscriptionPlanDetailView()
        } label: {
            LabeledContent {
                if accessManager.isDirectSubscriber {
                    PlanBadge()
                } else {
                    Text(currentPlanTitle)
                        .foregroundStyle(.secondary)
                }
            } label: {
                Label("plan.your", systemImage: iconName)
            }
        }
    }

    private var currentPlanTitle: String {
        if accessManager.isDirectSubscriberEnterprise { return String(localized: "plan.enterprise") }
        if accessManager.isDirectSubscriber { return String(localized: "plan.professional") }
        return String(localized: "plan.standard")
    }
    private var iconName: String {
        if accessManager.isDirectSubscriberEnterprise { return "crown.fill" }
        if accessManager.isDirectSubscriber { return "star.fill" }
        return "person.fill"
    }
}

struct SubscriptionPlanDetailView: View {
    @Environment(\.openURL) private var openURL
    @Environment(SnapshotsAccessManager.self) private var accessManager
    @State private var showingPaywall = false
    @State private var expandedStandard = false
    @State private var expandedPro = false
    @State private var expandedEnterprise = false
    @State private var alertMessage: String?

    var body: some View {
        List {
            Section {
                LabeledContent("plan.your", value: currentPlanTitle)
                if accessManager.isDirectSubscriber {
                    LabeledContent("paywall.current_plan") {
                        PlanBadge()
                    }
                }
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("plan.plans") {
                planDisclosure(
                    title: String(localized: "plan.standard"),
                    icon: "person.fill",
                    tint: .secondary,
                    isExpanded: $expandedStandard,
                    highlights: [
                        String(localized: "plan.standard.feature_1"),
                        String(localized: "plan.standard.feature_2"),
                        String(localized: "plan.standard.feature_3")
                    ],
                    note: String(localized: "plan.standard.note")
                )

                planDisclosure(
                    title: String(localized: "plan.professional"),
                    icon: "star.fill",
                    tint: .accentColor,
                    isExpanded: $expandedPro,
                    highlights: [
                        String(localized: "plan.professional.feature_1"),
                        String(localized: "plan.professional.feature_2"),
                        String(localized: "plan.professional.feature_3"),
                        String(localized: "plan.professional.feature_4")
                    ],
                    note: String(localized: "plan.professional.note")
                )

                planDisclosure(
                    title: String(localized: "plan.enterprise"),
                    icon: "crown.fill",
                    tint: .orange,
                    isExpanded: $expandedEnterprise,
                    highlights: [
                        String(localized: "plan.enterprise.feature_1"),
                        String(localized: "plan.enterprise.feature_2"),
                        String(localized: "plan.enterprise.feature_3"),
                        String(localized: "plan.enterprise.feature_4")
                    ],
                    note: String(localized: "plan.enterprise.note")
                )
            }

            if !accessManager.isDirectSubscriber {
                Section {
                    Button("plan.choose_paid") {
                        showingPaywall = true
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Section {
                Button("paywall.restore_purchases") {
                    Task {
                        do {
                            try await AppStore.sync()
                        } catch {
                            alertMessage = String(localized: "paywall.restore_failed")
                        }
                        await accessManager.updateSubscriptionStatus()
                    }
                }
                Button("paywall.terms") { openLegalURL(EnvConfig.termsOfServiceURL) }
                Button("paywall.privacy") { openLegalURL(EnvConfig.privacyPolicyURL) }
            } header: {
                Text("paywall.legal")
            }
        }
        .applySubscriptionListStyle()
        .navigationTitle("plan.your")
        .platformInlineNavigationTitleDisplayMode()
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .alert("paywall.subscription", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear(perform: syncExpandedPlan)
        .onChange(of: accessManager.isDirectSubscriber) { _, _ in
            syncExpandedPlan()
        }
        .onChange(of: accessManager.isDirectSubscriberEnterprise) { _, _ in
            syncExpandedPlan()
        }
    }

    private var currentPlanTitle: String {
        if accessManager.isDirectSubscriberEnterprise { return String(localized: "plan.enterprise") }
        if accessManager.isDirectSubscriber { return String(localized: "plan.professional") }
        return String(localized: "plan.standard")
    }

    private var summaryText: String {
        if accessManager.isDirectSubscriberEnterprise {
            return String(localized: "plan.summary.enterprise")
        }
        if accessManager.isDirectSubscriber {
            return String(localized: "plan.summary.professional")
        }
        return String(localized: "plan.summary.standard")
    }

    private func syncExpandedPlan() {
        expandedStandard = !accessManager.isDirectSubscriber
        expandedPro = accessManager.isDirectSubscriber && !accessManager.isDirectSubscriberEnterprise
        expandedEnterprise = accessManager.isDirectSubscriberEnterprise
    }

    @ViewBuilder
    private func planDisclosure(
        title: String,
        icon: String,
        tint: Color,
        isExpanded: Binding<Bool>,
        highlights: [String],
        note: String
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            ForEach(highlights, id: \.self) { item in
                Label {
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }

            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        } label: {
            Label(title, systemImage: icon)
                .foregroundStyle(tint)
        }
    }

    private func openLegalURL(_ url: URL?) {
        guard let url else {
            alertMessage = String(localized: "paywall.legal_missing")
            return
        }
        openURL(url)
    }
}

private extension View {
    @ViewBuilder
    func applySubscriptionListStyle() -> some View {
#if os(iOS)
        self.listStyle(.insetGrouped)
#else
        self.listStyle(.inset)
#endif
    }

}
