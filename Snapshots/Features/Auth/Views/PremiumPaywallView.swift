import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    private let accessManager = SnapshotsAccessManager.shared
    @State private var products: [Product] = []
    @State private var isLoadingProducts = true
    @State private var isPurchasing = false
    @State private var alertMessage: String?
    @State private var productLoadError: String?

    private let proMonthlyProductId = "com.ulukskywalker.snapshots.pro.monthly"
    private let proYearlyProductId = "com.ulukskywalker.snapshots.pro.yearly"

    var body: some View {
        NavigationStack {
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

                if isLoadingProducts || accessManager.isCheckingAccess {
                    Section {
                        ProgressView("paywall.loading_plans")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if !products.isEmpty {
                    if let proMonthlyProduct = products.first(where: { $0.id == proMonthlyProductId }) {
                        Section {
                            LabeledContent("plan.professional") {
                                Text(String(format: NSLocalizedString("paywall.price_per_month", comment: ""), proMonthlyProduct.displayPrice))
                                    .foregroundStyle(.secondary)
                            }
                            paywallAction(for: proMonthlyProduct, isActive: accessManager.activeSubscription?.id == proMonthlyProduct.id)
                            if let proYearlyProduct = products.first(where: { $0.id == proYearlyProductId }) {
                                LabeledContent("paywall.yearly_plan") {
                                    Text(String(format: NSLocalizedString("paywall.price_per_year", comment: ""), proYearlyProduct.displayPrice))
                                        .foregroundStyle(.secondary)
                                }
                                paywallAction(for: proYearlyProduct, isActive: accessManager.activeSubscription?.id == proYearlyProduct.id)
                            }
                            Text("paywall.professional.feature_1")
                            Text("paywall.professional.feature_2")
                            Text("paywall.professional.feature_3")
                            Text("paywall.professional.feature_4")
                        } header: {
                            Text("plan.professional")
                        }
                    }

                    Section {
                        Text("plan.business.feature_1")
                        Text("plan.business.feature_2")
                        Text("plan.business.feature_3")
                    } header: {
                        Text("plan.business")
                    } footer: {
                        Text("plan.business.note")
                    }
                } else {
                    Section {
                        Text(productLoadError ?? String(localized: "paywall.unavailable_message"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("common.try_again") {
                            Task { await loadProducts() }
                        }
                    } header: {
                        Text("paywall.paid_plans")
                    }
                }

                Section {
                    Text("paywall.all_plans.feature_1")
                    Text("paywall.all_plans.feature_2")
                    Text("paywall.all_plans.feature_3")
                    Text("paywall.all_plans.feature_4")
                } header: {
                    Text("paywall.all_plans")
                } footer: {
                    Text("paywall.all_plans_footer")
                }

            }
            .navigationTitle("paywall.choose_plan")
            .applyInlineNavigationTitleIfSupported()
            .toolbar {
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
