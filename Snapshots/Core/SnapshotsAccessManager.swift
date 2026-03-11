import Foundation
import SwiftUI
import StoreKit
import Supabase

@Observable @MainActor
final class SnapshotsAccessManager {
    static let shared = SnapshotsAccessManager()
    
    var profile: ProfileModel?
    var isCheckingAccess = true
    var activeSubscription: Product?
    var activeProductTier: String = "free"
    private var transactionUpdatesTask: Task<Void, Never>?
    private var productCache: [String: Product] = [:]
    
    private let proProductId = "com.ulukskywalker.snapshots.pro"
    private let enterpriseProductId = "com.ulukskywalker.snapshots.enterprise"
    
    private init() {
        Task {
            await self.initialize()
        }
    }
    
    private func initialize() async {
        isCheckingAccess = true
        await fetchProfile()
        await cacheSubscriptionProductsIfNeeded()
        await updateSubscriptionStatus()
        startListeningForTransactionUpdates()
        isCheckingAccess = false
    }
    
    var isPro: Bool {
        if isCheckingAccess { return false }
        return isDirectSubscriber
    }

    var isEnterprise: Bool {
        if isCheckingAccess { return false }
        return isDirectSubscriberEnterprise
    }

    var isDirectSubscriber: Bool {
        (profile?.isPro ?? false) || activeProductTier != "free"
    }

    var isDirectSubscriberEnterprise: Bool {
        (profile?.isEnterprise ?? false) || activeProductTier == "enterprise"
    }
    
    func refreshProfile() async {
        await fetchProfile()
    }

    private func fetchProfile() async {
        do {
            let session = try await supabase.auth.session
            let user = session.user
            let fetchedProfile: ProfileModel = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: user.id.uuidString.lowercased())
                .single()
                .execute()
                .value
            self.profile = fetchedProfile
        } catch {
            print("Access Manager: Error fetching profile: \(error)")
        }
    }

    func refreshEntitlementsForCurrentUser() async {
        await reloadEntitlements()
    }

    func clearEntitlementsForSignedOutUser() {
        profile = nil
        activeSubscription = nil
        activeProductTier = "free"
        isCheckingAccess = false
    }
    
    // MARK: - StoreKit 2 Logic
    
    func updateSubscriptionStatus() async {
        let highestTierFound = await currentEntitledTier()
        self.activeProductTier = highestTierFound
        if let productID = productID(forTier: highestTierFound) {
            self.activeSubscription = productCache[productID]
        } else {
            self.activeSubscription = nil
        }
    }

    private func startListeningForTransactionUpdates() {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [weak self] in
            guard let self else { return }
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self.updateSubscriptionStatus()
            }
        }
    }
    
    private func reloadEntitlements() async {
        isCheckingAccess = true
        await fetchProfile()
        await cacheSubscriptionProductsIfNeeded()
        await updateSubscriptionStatus()
        isCheckingAccess = false
    }

    private func cacheSubscriptionProductsIfNeeded() async {
        guard productCache.isEmpty else { return }
        do {
            let products = try await Product.products(for: [proProductId, enterpriseProductId])
            productCache = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            print("Access Manager: Product cache error: \(error)")
        }
    }

    private func currentEntitledTier() async -> String {
        var highestTierFound = "free"

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard transaction.expirationDate == nil || transaction.expirationDate! > Date() else { continue }

            if transaction.productID == enterpriseProductId {
                return "enterprise"
            }

            if transaction.productID == proProductId {
                highestTierFound = "pro"
            }
        }

        return highestTierFound
    }

    private func productID(forTier tier: String) -> String? {
        switch tier {
        case "enterprise":
            enterpriseProductId
        case "pro":
            proProductId
        default:
            nil
        }
    }
    
    // MARK: - Property-Specific Access Logic
    
    func isPro(for property: PropertyModel?) -> Bool {
        hasAccess(
            directAccess: isDirectSubscriber,
            ownerTier: property?.ownerTier,
            matchingTiers: ["pro", "enterprise", "lifetime"]
        )
    }

    func isEnterprise(for property: PropertyModel?) -> Bool {
        hasAccess(
            directAccess: isDirectSubscriberEnterprise,
            ownerTier: property?.ownerTier,
            matchingTiers: ["enterprise", "lifetime"]
        )
    }

    // MARK: - Helper Methods

    func canAddProperty(ownedCount: Int) -> Bool {
        if isDirectSubscriberEnterprise { return true }
        if isDirectSubscriber { return ownedCount < 10 }
        return ownedCount < 1
    }

    func canAddTeamMember(for property: PropertyModel?, currentMemberCount: Int) -> Bool {
        if isEnterprise(for: property) { return true }
        if isPro(for: property) { return currentMemberCount < 5 }
        return false
    }

    private func hasAccess(directAccess: Bool, ownerTier: String?, matchingTiers: Set<String>) -> Bool {
        if isCheckingAccess { return false }
        if directAccess { return true }
        guard let ownerTier else { return false }
        return matchingTiers.contains(ownerTier)
    }
}
