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

        // 3. Check StoreKit 2 for active subscription
        await self.updateSubscriptionStatus()

        isCheckingAccess = false
    }
    
    var isPro: Bool {
        if isCheckingAccess { return false }
        if self.isSandbox() { return true }
        if self.profile?.isPro ?? false { return true }
        return activeProductTier != "free"
    }

    var isEnterprise: Bool {
        if isCheckingAccess { return false }
        if self.isSandbox() { return true }
        if self.profile?.isEnterprise ?? false { return true }
        return activeProductTier == "enterprise"
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
    
    // MARK: - StoreKit 2 Logic
    
    func updateSubscriptionStatus() async {
        do {
            var highestTierFound = "free"
            var foundProduct: Product?

            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else { continue }
                
                if transaction.revocationDate == nil && (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                    if transaction.productID == enterpriseProductId {
                        highestTierFound = "enterprise"
                        let products = try await Product.products(for: [enterpriseProductId])
                        foundProduct = products.first
                        break // Enterprise is the highest, no need to keep checking
                    } else if transaction.productID == proProductId {
                        highestTierFound = "pro"
                        let products = try await Product.products(for: [proProductId])
                        foundProduct = products.first
                    }
                }
            }
            self.activeProductTier = highestTierFound
            self.activeSubscription = foundProduct
        } catch {
            print("Access Manager: StoreKit error: \(error)")
        }
    }
    
    // MARK: - Environment Detection
    
    private func checkIsSandbox() async -> Bool {
        #if targetEnvironment(simulator)
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
    
    // MARK: - Helper Methods
    
    func canAddProperty(currentCount: Int) -> Bool {
        if isEnterprise { return true }
        if isPro { return currentCount < 10 }
        return currentCount < 1
    }
}
