import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    private let accessManager = SnapshotsAccessManager.shared
    @State private var products: [Product] = []
    @State private var isLoadingProducts = true
    @State private var isPurchasing = false
    @State private var alertMessage: String?
    @State private var productLoadError: String?

    private let proProductId = "com.ulukskywalker.snapshots.pro"
    private let enterpriseProductId = "com.ulukskywalker.snapshots.enterprise"

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Current Plan Header
                Section {
                    if accessManager.isCheckingAccess {
                        HStack {
                            Spacer()
                            ProgressView("paywall.current_plan")
                            Spacer()
                        }
                    } else {
                        LabeledContent("paywall.current_plan") {
                            Label(currentPlanName, systemImage: currentPlanIcon)
                                .foregroundStyle(currentPlanColor)
                        }

                        ForEach(currentPlanFeatures, id: \.self) { feature in
                            Label(feature, systemImage: "checkmark")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: - Plans
                if isLoadingProducts || accessManager.isCheckingAccess {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("paywall.loading_plans")
                            Spacer()
                        }
                    }
                } else if !products.isEmpty {
                    if let proProduct = products.first(where: { $0.id == proProductId }) {
                        Section {
                            LabeledContent("plan.professional") {
                                Text(String(format: NSLocalizedString("paywall.price_per_month", comment: ""), proProduct.displayPrice))
                                    .foregroundStyle(.secondary)
                            }
                            paywallAction(for: proProduct, isActive: accessManager.activeProductTier == "pro")
                            Label("paywall.professional.feature_1", systemImage: "checkmark")
                            Label("paywall.professional.feature_2", systemImage: "checkmark")
                            Label("paywall.professional.feature_3", systemImage: "checkmark")
                            Label("paywall.professional.feature_4", systemImage: "checkmark")
                        } header: {
                            Text("plan.professional")
                        }
                    }

                    if let entProduct = products.first(where: { $0.id == enterpriseProductId }) {
                        Section {
                            LabeledContent("plan.enterprise") {
                                Text(String(format: NSLocalizedString("paywall.price_per_month", comment: ""), entProduct.displayPrice))
                                    .foregroundStyle(.secondary)
                            }
                            paywallAction(for: entProduct, isActive: accessManager.activeProductTier == "enterprise")
                            Label("paywall.enterprise.feature_1", systemImage: "checkmark")
                            Label("paywall.enterprise.feature_2", systemImage: "checkmark")
                            Label("paywall.enterprise.feature_3", systemImage: "checkmark")
                        } header: {
                            Text("plan.enterprise")
                        }
                    }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("paywall.unavailable_title")
                                .font(.headline)
                            Text(productLoadError ?? String(localized: "paywall.unavailable_message"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            VStack(alignment: .leading, spacing: 6) {
                                Label("paywall.unavailable.check_1", systemImage: "checkmark.circle")
                                Label("paywall.unavailable.check_2", systemImage: "checkmark.circle")
                                Label("paywall.unavailable.check_3", systemImage: "checkmark.circle")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)

                            Button("common.try_again") {
                                Task { await loadProducts() }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("paywall.paid_plans")
                    }
                }

                // MARK: - Included in All Plans
                Section {
                    Label("paywall.all_plans.feature_1", systemImage: "checkmark.shield.fill")
                        .font(.subheadline)
                    Label("paywall.all_plans.feature_2", systemImage: "doc.text.fill")
                        .font(.subheadline)
                    Label("paywall.all_plans.feature_3", systemImage: "list.bullet.clipboard.fill")
                        .font(.subheadline)
                    Label("paywall.all_plans.feature_4", systemImage: "icloud.fill")
                        .font(.subheadline)
                } header: {
                    Text("paywall.all_plans")
                } footer: {
                    Text("paywall.all_plans_footer")
                }

                // MARK: - Legal
                Section {
                    Button("paywall.restore_purchases") {
                        Task {
                            do {
                                try await AppStore.sync()
                            } catch {
                                print("Paywall: Restore failed: \(error)")
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
            .listStyle(.insetGrouped)
            .navigationTitle("paywall.choose_plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
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
        if accessManager.isDirectSubscriberEnterprise { return String(localized: "plan.enterprise") }
        if accessManager.isDirectSubscriber { return String(localized: "plan.professional") }
        return String(localized: "plan.standard")
    }

    private var currentPlanIcon: String {
        if accessManager.isDirectSubscriberEnterprise { return "building.2.fill" }
        if accessManager.isDirectSubscriber { return "star.fill" }
        return "person.fill"
    }

    private var currentPlanColor: Color {
        if accessManager.isDirectSubscriberEnterprise { return .purple }
        if accessManager.isDirectSubscriber { return .accentColor }
        return .secondary
    }

    @ViewBuilder
    private func paywallAction(for product: Product, isActive: Bool) -> some View {
        if isActive {
            Label("paywall.current_plan", systemImage: "checkmark.circle.fill")
                .foregroundColor(.accentColor)
        } else {
            Button("paywall.subscribe") {
                Task { await purchase(product) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPurchasing)
        }
    }

    private var currentPlanFeatures: [String] {
        if accessManager.isDirectSubscriberEnterprise {
            return [
                String(localized: "paywall.enterprise.feature_2"),
                String(localized: "plan.enterprise.feature_2"),
                String(localized: "paywall.professional.feature_1"),
                String(localized: "paywall.professional.feature_4"),
                String(localized: "paywall.enterprise.feature_3"),
                String(localized: "paywall.all_plans.feature_1"),
                String(localized: "paywall.all_plans.feature_4")
            ]
        }
        if accessManager.isDirectSubscriber {
            return [
                String(localized: "paywall.professional.feature_2"),
                String(localized: "paywall.professional.feature_3"),
                String(localized: "paywall.professional.feature_1"),
                String(localized: "paywall.professional.feature_4"),
                String(localized: "paywall.all_plans.feature_1"),
                String(localized: "paywall.all_plans.feature_4")
            ]
        }
        return [
            String(localized: "plan.standard.feature_1"),
            String(localized: "paywall.all_plans.feature_1"),
            String(localized: "paywall.all_plans.feature_2"),
            String(localized: "paywall.all_plans.feature_3"),
            String(localized: "paywall.all_plans.feature_4")
        ]
    }

    private func loadProducts() async {
        isLoadingProducts = true
        productLoadError = nil
        do {
            self.products = try await Product.products(for: [proProductId, enterpriseProductId])
            if products.isEmpty {
                productLoadError = "No products were returned for product IDs `\(proProductId)` and `\(enterpriseProductId)`."
            } else {
                let loadedIds = Set(products.map(\.id))
                let expectedIds: Set<String> = [proProductId, enterpriseProductId]
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
                    await accessManager.updateSubscriptionStatus()
                    dismiss()
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

    private func openLegalURL(_ url: URL?) {
        guard let url else {
            alertMessage = String(localized: "paywall.legal_missing")
            return
        }
        openURL(url)
    }
}
