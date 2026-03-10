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
    private var _isSandbox = false
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

        // 1. Detect sandbox environment
        _isSandbox = await checkIsSandbox()

        // 2. Fetch Profile for VIP/Lifetime status
        await self.fetchProfile()

        // 3. Cache StoreKit products used by the paywall/subscription state.
        await cacheSubscriptionProductsIfNeeded()

        // 4. Check StoreKit 2 for active subscription
        await self.updateSubscriptionStatus()
        startListeningForTransactionUpdates()

        isCheckingAccess = false
    }
    
    var isPro: Bool {
        if isCheckingAccess { return false }
        if self.isSandbox() { return true }
        return isDirectSubscriber
    }

    var isEnterprise: Bool {
        if isCheckingAccess { return false }
        if self.isSandbox() { return true }
        return isDirectSubscriberEnterprise
    }

    var isDirectSubscriber: Bool {
        if self.profile?.isPro ?? false { return true }
        return activeProductTier != "free"
    }

    var isDirectSubscriberEnterprise: Bool {
        if self.profile?.isEnterprise ?? false { return true }
        return activeProductTier == "enterprise"
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
        isCheckingAccess = true
        await fetchProfile()
        await cacheSubscriptionProductsIfNeeded()
        await updateSubscriptionStatus()
        isCheckingAccess = false
    }

    func clearEntitlementsForSignedOutUser() {
        profile = nil
        activeSubscription = nil
        activeProductTier = "free"
        isCheckingAccess = false
    }
    
    // MARK: - StoreKit 2 Logic
    
    func updateSubscriptionStatus() async {
        var highestTierFound = "free"

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if transaction.revocationDate == nil && (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                if transaction.productID == enterpriseProductId {
                    highestTierFound = "enterprise"
                    break // Enterprise is the highest, no need to keep checking
                } else if transaction.productID == proProductId {
                    highestTierFound = "pro"
                }
            }
        }
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
    
    // MARK: - Environment Detection
    
    private func checkIsSandbox() async -> Bool {
        #if DEBUG
        return true
        #else
        if let result = try? await AppTransaction.shared,
           case .verified(let appTransaction) = result {
            return appTransaction.environment == .xcode || appTransaction.environment == .sandbox
        }
        return false
        #endif
    }

    private func isSandbox() -> Bool {
        _isSandbox
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
        if isCheckingAccess { return false }
        if self.isSandbox() { return true }
        if isDirectSubscriber { return true }
        // Inherit from owner of the specific property
        if let tier = property?.ownerTier {
            return tier == "pro" || tier == "enterprise" || tier == "lifetime"
        }
        return false
    }

    func isEnterprise(for property: PropertyModel?) -> Bool {
        if isCheckingAccess { return false }
        if self.isSandbox() { return true }
        if isDirectSubscriberEnterprise { return true }
        // Inherit from owner of the specific property
        if let tier = property?.ownerTier {
            return tier == "enterprise" || tier == "lifetime"
        }
        return false
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
}
