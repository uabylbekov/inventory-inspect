import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    var showsDismissButton: Bool = true

    var body: some View {
        NavigationStack {
            SubscriptionCenterView(showsDismissButton: showsDismissButton)
        }
    }
}

struct SubscriptionCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    private let accessManager = SnapshotsAccessManager.shared
    @State private var products: [Product] = []
    @State private var isLoadingProducts = true
    @State private var isPurchasing = false
    @State private var alertMessage: String?
    @State private var productLoadError: String?
    let showsDismissButton: Bool

    private let proMonthlyProductId = "com.ulukskywalker.snapshots.pro.monthly"
    private let proYearlyProductId = "com.ulukskywalker.snapshots.pro.yearly"

    var body: some View {
        List {
            Section {
                if accessManager.isCheckingAccess {
                    ProgressView("paywall.current_plan")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    LabeledContent("plan.your", value: currentPlanName)
                    Text(currentPlanSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("plan.plans") {
                planDisclosure(
                    title: String(localized: "plan.standard"),
                    icon: "person.fill",
                    tint: .secondary,
                    note: String(localized: "plan.summary.standard"),
                    highlights: [
                        String(localized: "plan.standard.feature_1"),
                        String(localized: "plan.standard.feature_2"),
                        String(localized: "plan.standard.feature_3")
                    ]
                )

                Divider()

                professionalPlanSection

                Divider()

                planDisclosure(
                    title: String(localized: "plan.business"),
                    icon: "briefcase.fill",
                    tint: .orange,
                    note: String(localized: "plan.business.note"),
                    highlights: [
                        String(localized: "plan.business.feature_1"),
                        String(localized: "plan.business.feature_2"),
                        String(localized: "plan.business.feature_3"),
                        String(localized: "plan.business.feature_4")
                    ],
                    footer: businessContactFooter
                )
            }

            Section {
                Button("paywall.restore_purchases") {
                    Task { await restorePurchases() }
                }
            }
        }
        .navigationTitle("plan.your")
        .applyInlineNavigationTitleIfSupported()
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
        .task {
            await loadProducts()
        }
        .alert("paywall.subscription", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var currentPlanName: String {
        if accessManager.hasBusinessAccess { return String(localized: "plan.business") }
        if accessManager.hasDirectPaidAccess { return String(localized: "plan.professional") }
        return String(localized: "plan.standard")
    }

    @ViewBuilder
    private func paywallAction(for product: Product, isActive: Bool) -> some View {
        if accessManager.hasBusinessAccess || isActive {
            Text("paywall.current_plan")
                .foregroundColor(.secondary)
        } else {
            Button("paywall.subscribe") {
                Task { await purchase(product) }
            }
            .disabled(isPurchasing)
        }
    }

    private var currentPlanSummary: String {
        if accessManager.hasBusinessAccess {
            return String(localized: "plan.summary.business")
        }
        if accessManager.hasDirectPaidAccess {
            return String(localized: "plan.summary.professional")
        }
        return String(localized: "plan.summary.standard")
    }

    @ViewBuilder
    private var professionalPlanSection: some View {
        if isLoadingProducts || accessManager.isCheckingAccess {
            ProgressView("paywall.loading_plans")
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let proMonthlyProduct = products.first(where: { $0.id == proMonthlyProductId }) {
            VStack(alignment: .leading, spacing: 12) {
                Label("plan.professional", systemImage: "star.fill")
                    .foregroundStyle(Color.accentColor)

                LabeledContent {
                    Text(String(format: NSLocalizedString("paywall.price_per_month", comment: ""), proMonthlyProduct.displayPrice))
                        .foregroundStyle(.secondary)
                } label: {
                    Text("Monthly")
                }
                paywallAction(for: proMonthlyProduct, isActive: accessManager.activeSubscription?.id == proMonthlyProduct.id)

                if let proYearlyProduct = products.first(where: { $0.id == proYearlyProductId }) {
                    Divider()
                    LabeledContent("paywall.yearly_plan") {
                        Text(String(format: NSLocalizedString("paywall.price_per_year", comment: ""), proYearlyProduct.displayPrice))
                            .foregroundStyle(.secondary)
                    }
                    paywallAction(for: proYearlyProduct, isActive: accessManager.activeSubscription?.id == proYearlyProduct.id)
                }

                Divider()

                featureList([
                    String(localized: "paywall.professional.feature_1"),
                    String(localized: "paywall.professional.feature_2"),
                    String(localized: "paywall.professional.feature_3"),
                    String(localized: "paywall.professional.feature_4")
                ])

                Text(String(localized: "plan.professional.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(productLoadError ?? String(localized: "paywall.unavailable_message"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("common.try_again") {
                    Task { await loadProducts() }
                }
            }
        }
    }

    @ViewBuilder
    private func planDisclosure(
        title: String,
        icon: String,
        tint: Color,
        note: String,
        highlights: [String],
        footer: AnyView? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .foregroundStyle(tint)

            featureList(highlights)

            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let footer {
                footer
            }
        }
        .padding(.vertical, 4)
    }

    private var businessContactFooter: AnyView {
        AnyView(
            Button {
                if let emailURL = URL(string: "mailto:support@uluksywalker.com") {
                    openURL(emailURL)
                }
            } label: {
                Text("Contact support@uluksywalker.com for quota changes.")
                    .font(.caption)
            }
        )
    }

    @ViewBuilder
    private func featureList(_ items: [String]) -> some View {
        ForEach(items, id: \.self) { item in
            Label {
                Text(item)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private func loadProducts() async {
        isLoadingProducts = true
        productLoadError = nil

        do {
            self.products = try await Product.products(for: [proMonthlyProductId, proYearlyProductId])
            if products.isEmpty {
                productLoadError = "No products were returned for the configured Pro product IDs."
            } else {
                let loadedIds = Set(products.map(\.id))
                let expectedIds: Set<String> = [proMonthlyProductId, proYearlyProductId]
                let missingIds = expectedIds.subtracting(loadedIds)
                if !missingIds.isEmpty {
                    let missingPlanList = missingIds.sorted().joined(separator: ", ")
                    productLoadError = "Some plans are missing from App Store Connect for this build: \(missingPlanList)."
                }
            }
        } catch {
            print("Paywall: Failed to load products: \(error)")
            productLoadError = error.localizedDescription
            products = []
        }
        isLoadingProducts = false
    }

    private func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            alertMessage = String(localized: "paywall.restore_failed")
            return
        }
        await accessManager.refreshEntitlementsForCurrentUser()
        if let syncError = accessManager.lastBillingSyncError {
            alertMessage = syncError
        } else if accessManager.hasDirectPaidAccess {
            alertMessage = "Purchases restored successfully."
        } else {
            alertMessage = "No active App Store subscription was found for this account."
        }
    }

    private func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await accessManager.refreshEntitlementsForCurrentUser()
                    if let syncError = accessManager.lastBillingSyncError {
                        alertMessage = syncError
                    } else {
                        dismiss()
                    }
                } else {
                    alertMessage = String(localized: "paywall.purchase_unverified")
                }
            case .userCancelled, .pending:
                if case .pending = result {
                    alertMessage = String(localized: "paywall.purchase_pending")
                }
            @unknown default:
                alertMessage = String(localized: "paywall.purchase_unexpected")
            }
        } catch {
            print("Paywall: Purchase failed: \(error)")
            alertMessage = String(localized: "paywall.purchase_failed")
        }
    }
}

private extension View {
    @ViewBuilder
    func applyInlineNavigationTitleIfSupported() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }
}
