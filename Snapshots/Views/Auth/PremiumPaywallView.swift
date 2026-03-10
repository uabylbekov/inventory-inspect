import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    private let accessManager = SnapshotsAccessManager.shared
    @State private var products: [Product] = []
    @State private var isLoadingProducts = true

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
                                Text("Current Plan")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
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
                            ProgressView("Loading Plans...")
                            Spacer()
                        }
                    }
                } else {
                    if let proProduct = products.first(where: { $0.id == proProductId }) {
                        Section {
                            PlanRow(
                                icon: "star.fill",
                                iconColor: .accentColor,
                                name: "Professional",
                                price: proProduct.displayPrice,
                                isActive: accessManager.activeProductTier == "pro",
                                action: { Task { await purchase(proProduct) } }
                            )
                            FeatureRow("Photo Attachments on Inspections")
                            FeatureRow("Up to 10 Properties")
                            FeatureRow("Up to 5 Managers")
                            FeatureRow("Custom Company Logo on PDFs")
                        } header: {
                            Text("Professional")
                        }
                    }

                    if let entProduct = products.first(where: { $0.id == enterpriseProductId }) {
                        Section {
                            PlanRow(
                                icon: "building.2.fill",
                                iconColor: .purple,
                                name: "Enterprise",
                                price: entProduct.displayPrice,
                                isActive: accessManager.activeProductTier == "enterprise",
                                action: { Task { await purchase(entProduct) } }
                            )
                            FeatureRow("Everything in Professional")
                            FeatureRow("Unlimited Properties & Managers")
                            FeatureRow("Full White-label PDF Reports")
                        } header: {
                            Text("Enterprise")
                        }
                    }
                }

                // MARK: - Included in All Plans
                Section {
                    Label("Unlimited Inspections", systemImage: "checkmark.shield.fill")
                        .font(.subheadline)
                    Label("PDF Report Generation", systemImage: "doc.text.fill")
                        .font(.subheadline)
                    Label("Room & Inventory Tracking", systemImage: "list.bullet.clipboard.fill")
                        .font(.subheadline)
                    Label("Cloud Backup", systemImage: "icloud.fill")
                        .font(.subheadline)
                } header: {
                    Text("All Plans Include")
                } footer: {
                    Text("Photo attachments and team collaboration require a paid plan.")
                }

                // MARK: - Legal
                Section {
                    Button("Restore Purchases") {
                        Task { await accessManager.updateSubscriptionStatus() }
                    }
                    Button("Terms of Service") { }
                    Button("Privacy Policy") { }
                } header: {
                    Text("Legal")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Choose a Plan")
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
    }

    private var currentPlanName: String {
        if accessManager.isEnterprise { return "Enterprise" }
        if accessManager.isPro { return "Professional" }
        return "Standard"
    }

    private var currentPlanIcon: String {
        if accessManager.isEnterprise { return "building.2.fill" }
        if accessManager.isPro { return "star.fill" }
        return "person.fill"
    }

    private var currentPlanColor: Color {
        if accessManager.isEnterprise { return .purple }
        if accessManager.isPro { return .accentColor }
        return .secondary
    }

    private var currentPlanFeatures: [String] {
        if accessManager.isEnterprise {
            return [
                "Unlimited Properties",
                "Unlimited Team Members",
                "Photo Attachments on Inspections",
                "Company Logo on PDFs",
                "Full White-label PDF Reports",
                "Unlimited Inspections",
                "Cloud Backup"
            ]
        }
        if accessManager.isPro {
            return [
                "Up to 10 Properties",
                "Up to 5 Team Members",
                "Photo Attachments on Inspections",
                "Custom Company Logo on PDFs",
                "Unlimited Inspections",
                "Cloud Backup"
            ]
        }
        return [
            "1 Property",
            "Unlimited Inspections",
            "PDF Report Generation",
            "Room & Inventory Tracking",
            "Cloud Backup"
        ]
    }

    private func loadProducts() async {
        isLoadingProducts = true
        do {
            self.products = try await Product.products(for: [proProductId, enterpriseProductId])
        } catch {
            print("Paywall: Failed to load products: \(error)")
        }
        isLoadingProducts = false
    }

    private func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await accessManager.updateSubscriptionStatus()
                    dismiss()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("Paywall: Purchase failed: \(error)")
        }
    }
}

private struct PlanRow: View {
    let icon: String
    let iconColor: Color
    let name: String
    let price: String
    let isActive: Bool
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
                Text("\(price) / month")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            } else {
                Button("Subscribe", action: action)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(iconColor))
                    .foregroundColor(.white)
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
        }
    }
}
