import Foundation
import SwiftUI
import StoreKit
import Supabase

@Observable @MainActor
final class SnapshotsAccessManager {
    static let shared = SnapshotsAccessManager()

    struct TierLimits {
        let propertyLimit: Int
        let teamLimit: Int
        let photoLimit: Int
    }

    enum PhotoAttachmentError: LocalizedError {
        case photoLimitReached(used: Int, limit: Int)

        var errorDescription: String? {
            switch self {
            case .photoLimitReached(let used, let limit):
                return "Photo limit reached (\(used)/\(limit)). Upgrade your plan to save more evidence."
            }
        }
    }

    var profile: ProfileModel?
    var isCheckingAccess = true
    var activeSubscription: Product?
    var activeProductTier: String = "free"
    var photoUsageCount = 0
    private var transactionUpdatesTask: Task<Void, Never>?
    private var productCache: [String: Product] = [:]
    private var activeProductID: String?

    private let proMonthlyProductId = "com.ulukskywalker.snapshots.pro.monthly"
    private let proYearlyProductId = "com.ulukskywalker.snapshots.pro.yearly"
    private let defaultFreeLimits = TierLimits(propertyLimit: 1, teamLimit: 0, photoLimit: 150)
    private let defaultProLimits = TierLimits(propertyLimit: 10, teamLimit: 3, photoLimit: 10_000)
    private let defaultBusinessLimits = TierLimits(propertyLimit: 50, teamLimit: 20, photoLimit: 50_000)
    
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
        await refreshPhotoUsageForCurrentUser()
        startListeningForTransactionUpdates()
        isCheckingAccess = false
    }
    
    var isPro: Bool {
        if isCheckingAccess { return false }
        return hasDirectPaidAccess
    }

    var isBusiness: Bool {
        if isCheckingAccess { return false }
        return hasBusinessAccess
    }

    var hasStoreKitProSubscription: Bool {
        activeProductTier == "pro"
    }

    var hasDirectPaidAccess: Bool {
        (profile?.hasProFeatures ?? false) || hasStoreKitProSubscription
    }

    var hasBusinessAccess: Bool {
        profile?.hasBusinessFeatures ?? false
    }

    var directTierLimits: TierLimits {
        resolvedLimits(
            subscriptionTier: profile?.subscription_tier,
            propertyLimitOverride: profile?.property_limit_override,
            teamLimitOverride: profile?.team_limit_override,
            photoLimitOverride: profile?.photo_limit_override,
            hasStoreKitPro: hasStoreKitProSubscription
        )
    }
    
    func refreshProfile() async {
        await fetchProfile()
        await refreshPhotoUsageForCurrentUser()
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
        activeProductID = nil
        photoUsageCount = 0
        isCheckingAccess = false
    }
    
    // MARK: - StoreKit 2 Logic
    
    func updateSubscriptionStatus() async {
        let entitlement = await currentEntitledTier()
        self.activeProductTier = entitlement.tier
        self.activeProductID = entitlement.productID
        if let productID = entitlement.productID ?? productID(forTier: entitlement.tier) {
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
        await refreshPhotoUsageForCurrentUser()
        isCheckingAccess = false
    }

    private func cacheSubscriptionProductsIfNeeded() async {
        guard productCache.isEmpty else { return }
        do {
            let products = try await Product.products(for: [proMonthlyProductId, proYearlyProductId])
            productCache = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            print("Access Manager: Product cache error: \(error)")
        }
    }

    private func currentEntitledTier() async -> (tier: String, productID: String?) {
        var highestTierFound = "free"
        var matchedProductID: String?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard transaction.expirationDate == nil || transaction.expirationDate! > Date() else { continue }

            if [proMonthlyProductId, proYearlyProductId].contains(transaction.productID) {
                highestTierFound = "pro"
                matchedProductID = transaction.productID
            }
        }

        return (highestTierFound, matchedProductID)
    }

    private func productID(forTier tier: String) -> String? {
        switch tier {
        case "pro":
            activeProductID ?? proMonthlyProductId
        default:
            nil
        }
    }
    
    // MARK: - Property-Specific Access Logic
    
    func isPro(for property: PropertyModel?) -> Bool {
        hasAccess(
            directAccess: hasDirectPaidAccess,
            ownerTier: property?.ownerTier,
            matchingTiers: ["pro", "business", "lifetime"]
        )
    }

    func isBusiness(for property: PropertyModel?) -> Bool {
        hasAccess(
            directAccess: hasBusinessAccess,
            ownerTier: property?.ownerTier,
            matchingTiers: ["business", "lifetime"]
        )
    }

    // MARK: - Helper Methods

    func canAddProperty(ownedCount: Int) -> Bool {
        ownedCount < directTierLimits.propertyLimit
    }

    func canAddTeamMember(for property: PropertyModel?, currentMemberCount: Int) -> Bool {
        currentMemberCount < tierLimits(for: property).teamLimit
    }

    func canAttachPhoto(to property: PropertyModel?, existingImageURL: String?) async -> Result<Void, PhotoAttachmentError> {
        guard let ownerId = property?.owner_id ?? profile?.id else {
            return .success(())
        }

        let limits = tierLimits(for: property)
        let usage = await loadOwnerPhotoUsage(ownerId: ownerId)

        if ownerId == profile?.id {
            photoUsageCount = usage
        }

        if existingImageURL != nil || usage < limits.photoLimit {
            return .success(())
        }

        return .failure(.photoLimitReached(used: usage, limit: limits.photoLimit))
    }

    private func hasAccess(directAccess: Bool, ownerTier: String?, matchingTiers: Set<String>) -> Bool {
        if isCheckingAccess { return false }
        if directAccess { return true }
        guard let ownerTier else { return false }
        return matchingTiers.contains(ownerTier)
    }

    func refreshPhotoUsageForCurrentUser() async {
        guard let ownerId = profile?.id else {
            photoUsageCount = 0
            return
        }

        photoUsageCount = await loadOwnerPhotoUsage(ownerId: ownerId)
    }

    private func tierLimits(for property: PropertyModel?) -> TierLimits {
        if let property {
            if property.owner_id == profile?.id {
                return directTierLimits
            }

            return resolvedLimits(
                subscriptionTier: property.ownerTier,
                propertyLimitOverride: property.owner?.property_limit_override,
                teamLimitOverride: property.owner?.team_limit_override,
                photoLimitOverride: property.owner?.photo_limit_override,
                hasStoreKitPro: false
            )
        }

        return directTierLimits
    }

    private func resolvedLimits(
        subscriptionTier: String?,
        propertyLimitOverride: Int?,
        teamLimitOverride: Int?,
        photoLimitOverride: Int?,
        hasStoreKitPro: Bool
    ) -> TierLimits {
        let baseLimits: TierLimits
        if subscriptionTier == "business" || subscriptionTier == "lifetime" {
            baseLimits = defaultBusinessLimits
        } else if subscriptionTier == "pro" || hasStoreKitPro {
            baseLimits = defaultProLimits
        } else {
            baseLimits = defaultFreeLimits
        }

        return TierLimits(
            propertyLimit: propertyLimitOverride ?? baseLimits.propertyLimit,
            teamLimit: teamLimitOverride ?? baseLimits.teamLimit,
            photoLimit: photoLimitOverride ?? baseLimits.photoLimit
        )
    }

    private func loadOwnerPhotoUsage(ownerId: UUID) async -> Int {
        do {
            return try await PlanUsageService.loadOwnerPhotoUsage(ownerId: ownerId)
        } catch {
            print("Access Manager: Photo usage error: \(error)")
            return 0
        }
    }
}
