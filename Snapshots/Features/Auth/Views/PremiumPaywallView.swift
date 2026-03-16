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
    @State private var accessManager = SnapshotsAccessManager.shared
    @State private var products: [Product] = []
    @State private var isLoadingProducts = true
    @State private var purchasingProductID: String?
    @State private var alertMessage: String?
    @State private var productLoadError: String?
    @State private var legalAlertMessage: String?
    let showsDismissButton: Bool

    private let proMonthlyProductId = "dev.ukulabs.snapshots.subscription.pro.monthly"
    private let proYearlyProductId = "dev.ukulabs.snapshots.subscription.pro.yearly"

    var body: some View {
        List {
            Section {
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(currentPlanName)
                        if accessManager.isCheckingAccess {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                } label: {
                    Label {
                        Text("plan.your")
                    } icon: {
                        Image(systemName: currentPlanIcon)
                            .foregroundStyle(currentPlanTint)
                    }
                }
                Text(currentPlanSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                featureList([
                    String(localized: "plan.standard.feature_1"),
                    String(localized: "plan.standard.feature_2"),
                    String(localized: "plan.standard.feature_3")
                ])
            } header: {
                planSectionHeader(
                    title: String(localized: "plan.standard"),
                    icon: "person.fill",
                    tint: .secondary
                )
            } footer: {
                Text("plan.standard.note")
            }

            Section {
                professionalPlanSection
            } header: {
                planSectionHeader(
                    title: String(localized: "plan.professional"),
                    icon: "star.fill",
                    tint: .accentColor
                )
            } footer: {
                Text("plan.professional.note")
            }

            Section {
                featureList([
                    String(localized: "plan.business.feature_1"),
                    String(localized: "plan.business.feature_2"),
                    String(localized: "plan.business.feature_3"),
                    String(localized: "plan.business.feature_4")
                ])
                businessContactFooter
            } header: {
                planSectionHeader(
                    title: String(localized: "plan.business"),
                    icon: "briefcase.fill",
                    tint: .orange
                )
            } footer: {
                Text("plan.business.note")
            }

            Section {
                Button {
                    Task { await restorePurchases() }
                } label: {
                    Label("paywall.restore_purchases", systemImage: "arrow.clockwise")
                }
                .disabled(isPurchasingAnyPlan || accessManager.isCheckingAccess)
            }

            Section {
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
        .alert("paywall.legal", isPresented: Binding(
            get: { legalAlertMessage != nil },
            set: { if !$0 { legalAlertMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) { legalAlertMessage = nil }
        } message: {
            Text(legalAlertMessage ?? "")
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
            Button(action: {
                Task { await purchase(product) }
            }) {
                Text("paywall.subscribe")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPurchasing(product) || accessManager.isCheckingAccess)
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

    private var currentPlanIcon: String {
        if accessManager.hasBusinessAccess { return "briefcase.fill" }
        if accessManager.hasDirectPaidAccess { return "star.fill" }
        return "person.fill"
    }

    private var currentPlanTint: Color {
        if accessManager.hasBusinessAccess { return .orange }
        if accessManager.hasDirectPaidAccess { return .accentColor }
        return .secondary
    }

    @ViewBuilder
    private var professionalPlanSection: some View {
        if isLoadingProducts && products.isEmpty {
            ProgressView("paywall.loading_plans")
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let proMonthlyProduct = products.first(where: { $0.id == proMonthlyProductId }) {
            Group {
                pricingRow(
                    title: String(localized: "paywall.monthly"),
                    icon: "calendar",
                    price: String(format: NSLocalizedString("paywall.price_per_month", comment: ""), proMonthlyProduct.displayPrice),
                    product: proMonthlyProduct,
                    isActive: accessManager.activeSubscription?.id == proMonthlyProduct.id
                )

                if let proYearlyProduct = products.first(where: { $0.id == proYearlyProductId }) {
                    pricingRow(
                        title: String(localized: "paywall.yearly_plan"),
                        icon: "calendar.badge.clock",
                        price: String(format: NSLocalizedString("paywall.price_per_year", comment: ""), proYearlyProduct.displayPrice),
                        product: proYearlyProduct,
                        isActive: accessManager.activeSubscription?.id == proYearlyProduct.id
                    )
                }

                featureList([
                    String(localized: "paywall.professional.feature_1"),
                    String(localized: "paywall.professional.feature_2"),
                    String(localized: "paywall.professional.feature_3"),
                    String(localized: "paywall.professional.feature_4")
                ])
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
                .disabled(isPurchasingAnyPlan || accessManager.isCheckingAccess)
            }
        }
    }

    private var businessContactFooter: AnyView {
        AnyView(
            Button {
                if let emailURL = URL(string: "mailto:support@ukulabs.dev") {
                    openURL(emailURL)
                }
            } label: {
                Label("paywall.contact_support", systemImage: "envelope")
                    .font(.caption)
            }
        )
    }

    private func pricingRow(title: String, icon: String, price: String, product: Product, isActive: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                Text(price)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            if accessManager.hasBusinessAccess || isActive {
                Text("paywall.current_plan")
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            } else {
                Button(action: {
                    Task { await purchase(product) }
                }) {
                    HStack(spacing: 6) {
                        if isPurchasing(product) {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("paywall.subscribe")
                    }
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                }
                .buttonStyle(.borderless)
                .disabled(isPurchasing(product) || accessManager.isCheckingAccess)
            }
        }
    }

    private var isPurchasingAnyPlan: Bool {
        purchasingProductID != nil
    }

    private func isPurchasing(_ product: Product) -> Bool {
        purchasingProductID == product.id
    }

    private func openLegalURL(_ url: URL?) {
        guard let url else {
            legalAlertMessage = String(localized: "paywall.legal_missing")
            return
        }
        openURL(url)
    }

    private func planSectionHeader(title: String, icon: String, tint: Color) -> some View {
        Label(title, systemImage: icon)
            .foregroundStyle(tint)
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
                productLoadError = String(localized: "paywall.products_missing")
            } else {
                let loadedIds = Set(products.map(\.id))
                let expectedIds: Set<String> = [proMonthlyProductId, proYearlyProductId]
                let missingIds = expectedIds.subtracting(loadedIds)
                if !missingIds.isEmpty {
                    let missingPlanList = missingIds.sorted().joined(separator: ", ")
                    productLoadError = String.localizedStringWithFormat(
                        NSLocalizedString("paywall.products_partial_missing", comment: ""),
                        missingPlanList
                    )
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
            alertMessage = String(localized: "paywall.restore_success")
        } else {
            alertMessage = String(localized: "paywall.restore_none_found")
        }
    }

    private func purchase(_ product: Product) async {
        guard !isPurchasingAnyPlan else { return }
        purchasingProductID = product.id
        defer { purchasingProductID = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await accessManager.refreshEntitlementsForCurrentUser()
                    if let syncError = accessManager.lastBillingSyncError {
                        alertMessage = syncError
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
