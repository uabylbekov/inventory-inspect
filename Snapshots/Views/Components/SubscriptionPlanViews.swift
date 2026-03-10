import SwiftUI

struct SubscriptionPlanRow: View {
    @Environment(SnapshotsAccessManager.self) private var accessManager

    var body: some View {
        NavigationLink {
            SubscriptionPlanDetailView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconBackground.gradient)
                        .frame(width: 34, height: 34)
                    Image(systemName: iconName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(iconForeground)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("plan.your")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Text(currentPlanTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if accessManager.isDirectSubscriber {
                    PlanBadge()
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var currentPlanTitle: String {
        if accessManager.isDirectSubscriberEnterprise { return String(localized: "plan.enterprise") }
        if accessManager.isDirectSubscriber { return String(localized: "plan.professional") }
        return String(localized: "plan.standard")
    }

    private var iconBackground: Color {
        accessManager.isDirectSubscriber ? .accentColor : Color.secondary.opacity(0.15)
    }

    private var iconForeground: Color {
        accessManager.isDirectSubscriber ? .white : .secondary
    }

    private var iconName: String {
        if accessManager.isDirectSubscriberEnterprise { return "crown.fill" }
        if accessManager.isDirectSubscriber { return "star.fill" }
        return "person.fill"
    }
}

struct SubscriptionPlanDetailView: View {
    @Environment(SnapshotsAccessManager.self) private var accessManager
    @State private var showingPaywall = false
    @State private var expandedStandard = false
    @State private var expandedPro = false
    @State private var expandedEnterprise = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(currentPlanTitle)
                            .font(.headline)
                        if accessManager.isDirectSubscriber {
                            PlanBadge()
                        }
                    }
                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
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
        }
        .listStyle(.insetGrouped)
        .navigationTitle("plan.your")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
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
            VStack(alignment: .leading, spacing: 8) {
                ForEach(highlights, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .padding(.top, 2)
                        Text(item)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(tint.opacity(0.14))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                        .foregroundColor(tint)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
