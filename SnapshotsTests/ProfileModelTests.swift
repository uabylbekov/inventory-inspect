import Foundation
import Testing
@testable import Snapshots

@Suite("Billing And Profile Logic")
struct BillingAndProfileLogicTests {
    @Test("BillingDateParser accepts fractional-second ISO dates")
    func parsesFractionalISO8601Dates() {
        let date = BillingDateParser.parse("2026-03-13T18:45:12.123Z")
        #expect(date != nil)
    }

    @Test("BillingDateParser accepts non-fractional ISO dates")
    func parsesNonFractionalISO8601Dates() {
        let date = BillingDateParser.parse("2026-03-13T18:45:12Z")
        #expect(date != nil)
    }

    @Test("BillingDateParser rejects invalid values")
    func rejectsInvalidDates() {
        #expect(BillingDateParser.parse("not-a-date") == nil)
    }

    @Test("Free tier upgrades to pro when App Store subscription is active and unexpired")
    func activeSyncedSubscriptionUpgradesProfileTier() {
        let profile = makeProfile(
            subscriptionTier: "free",
            appStoreSubscriptionActive: true,
            appStoreSubscriptionExpiresAt: futureISOString()
        )

        #expect(profile.effectiveSubscriptionTier == "pro")
        #expect(profile.hasProFeatures)
        #expect(!profile.hasBusinessFeatures)
    }

    @Test("Expired synced App Store subscription falls back to free tier")
    func expiredSyncedSubscriptionFallsBackToFree() {
        let profile = makeProfile(
            subscriptionTier: "free",
            appStoreSubscriptionActive: true,
            appStoreSubscriptionExpiresAt: pastISOString()
        )

        #expect(profile.effectiveSubscriptionTier == "free")
        #expect(!profile.hasProFeatures)
    }

    @Test("Business tier keeps business feature access")
    func businessTierKeepsBusinessFeatures() {
        let profile = makeProfile(subscriptionTier: "business")

        #expect(profile.effectiveSubscriptionTier == "business")
        #expect(profile.hasProFeatures)
        #expect(profile.hasBusinessFeatures)
    }
}
