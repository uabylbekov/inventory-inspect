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
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color.secondary.opacity(0.2).gradient)
                                .frame(width: 56, height: 56)
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: 100, height: 14)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(width: 70, height: 12)
                            }
                        }
                        .padding(.vertical, 6)
                    } else {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(currentPlanColor.gradient)
                                    .frame(width: 56, height: 56)
                                Image(systemName: currentPlanIcon)
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentPlanName)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text("paywall.current_plan")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 6)

                        ForEach(currentPlanFeatures, id: \.self) { feature in
                            FeatureRow(feature)
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
                            PlanRow(
                                icon: "star.fill",
                                iconColor: .accentColor,
                                name: String(localized: "plan.professional"),
                                price: proProduct.displayPrice,
                                isActive: accessManager.activeProductTier == "pro",
                                isBusy: isPurchasing,
                                action: { Task { await purchase(proProduct) } }
                            )
                            FeatureRow(String(localized: "paywall.professional.feature_1"))
                            FeatureRow(String(localized: "paywall.professional.feature_2"))
                            FeatureRow(String(localized: "paywall.professional.feature_3"))
                            FeatureRow(String(localized: "paywall.professional.feature_4"))
                        } header: {
                            Text("plan.professional")
                        }
                    }

                    if let entProduct = products.first(where: { $0.id == enterpriseProductId }) {
                        Section {
                            PlanRow(
                                icon: "building.2.fill",
                                iconColor: .purple,
                                name: String(localized: "plan.enterprise"),
                                price: entProduct.displayPrice,
                                isActive: accessManager.activeProductTier == "enterprise",
                                isBusy: isPurchasing,
                                action: { Task { await purchase(entProduct) } }
                            )
                            FeatureRow(String(localized: "paywall.enterprise.feature_1"))
                            FeatureRow(String(localized: "paywall.enterprise.feature_2"))
                            FeatureRow(String(localized: "paywall.enterprise.feature_3"))
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

private struct PlanRow: View {
    let icon: String
    let iconColor: Color
    let name: String
    let price: String
    let isActive: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.gradient)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(format: NSLocalizedString("paywall.price_per_month", comment: ""), price))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            } else {
                Button("paywall.subscribe", action: action)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(iconColor))
                    .foregroundColor(.white)
                    .disabled(isBusy)
            }
        }
    }
}

private struct FeatureRow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.accentColor)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
