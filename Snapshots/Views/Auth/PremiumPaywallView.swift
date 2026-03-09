import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var accessManager = SnapshotsAccessManager.shared
    @State private var products: [Product] = []
    @State private var isLoadingProducts = true
    
    private let proProductId = "com.ulukskywalker.snapshots.pro"
    private let enterpriseProductId = "com.ulukskywalker.snapshots.enterprise"
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "0F172A"), Color(hex: "1E293B")]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Hero Section
                        VStack(spacing: 16) {
                            Text("CHOOSE YOUR PLAN")
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.accentColor))
                                .foregroundColor(.white)
                                .padding(.top, 20)
                            
                            Text("Professional Property Management")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                        }
                        
                        // Pricing Cards
                        if isLoadingProducts {
                            ProgressView()
                                .tint(.white)
                                .padding(.vertical, 50)
                        } else {
                            VStack(spacing: 20) {
                                // Pro Plan
                                if let proProduct = products.first(where: { $0.id == proProductId }) {
                                    PlanCard(
                                        title: "PROFESSIONAL",
                                        price: proProduct.displayPrice,
                                        features: [
                                            "Up to 10 Properties",
                                            "Up to 5 Managers",
                                            "Custom Branding",
                                            "Priority Support"
                                        ],
                                        isSelected: accessManager.activeProductTier == "pro",
                                        action: { Task { await purchase(proProduct) } }
                                    )
                                }
                                
                                // Enterprise Plan
                                if let entProduct = products.first(where: { $0.id == enterpriseProductId }) {
                                    PlanCard(
                                        title: "ENTERPRISE",
                                        price: entProduct.displayPrice,
                                        features: [
                                            "Unlimited Properties",
                                            "Unlimited Managers",
                                            "White-label Reports",
                                            "Team Admin Tools"
                                        ],
                                        isPremium: true,
                                        isSelected: accessManager.activeProductTier == "enterprise",
                                        action: { Task { await purchase(entProduct) } }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Value Propositions
                        VStack(spacing: 20) {
                            Text("All Plans Include")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.top)
                            
                            HStack(spacing: 20) {
                                MiniFeature(icon: "camera.fill", text: "4K Evidence")
                                MiniFeature(icon: "doc.text.fill", text: "PDF Reports")
                                MiniFeature(icon: "icloud.fill", text: "Cloud Sync")
                            }
                        }
                        .padding(.horizontal)
                        
                        // Footer Links
                        HStack(spacing: 20) {
                            Button("Terms of Service") { }
                            Text("•")
                            Button("Privacy Policy") { }
                            Text("•")
                            Button("Restore") {
                                Task { await accessManager.updateSubscriptionStatus() }
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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

private struct ValueFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Color.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PlanCard: View {
    let title: String
    let price: String
    let features: [String]
    var isPremium: Bool = false
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title)
                        .font(.caption.bold())
                        .tracking(1)
                        .foregroundColor(isPremium ? .accentColor : .secondary)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(price)
                        .font(.title.bold())
                        .foregroundColor(.white)
                    Text("per month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.accentColor.opacity(0.7))
                            Text(feature)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.1), lineWidth: 2)
                    )
            )
        }
    }
}

private struct MiniFeature: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(.accentColor)
            Text(text)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hex Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
