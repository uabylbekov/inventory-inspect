import Testing
@testable import Snapshots

@Suite("Property Model Logic")
struct PropertyModelLogicTests {
    @Test("Owner display name prefers full name")
    func ownerDisplayNamePrefersFullName() {
        let property = makeProperty(
            owner: .init(
                subscription_tier: "free",
                full_name: "Jordan Lee",
                email: "owner@example.com",
                company_logo_url: nil,
                business_details: nil,
                property_limit_override: nil,
                team_limit_override: nil,
                photo_limit_override: nil,
                app_store_subscription_active: nil,
                app_store_subscription_expires_at: nil
            )
        )

        #expect(property.ownerDisplayName == "Jordan Lee")
    }

    @Test("Owner display name falls back to email prefix")
    func ownerDisplayNameFallsBackToEmailPrefix() {
        let property = makeProperty(
            owner: .init(
                subscription_tier: "free",
                full_name: nil,
                email: "owner@example.com",
                company_logo_url: nil,
                business_details: nil,
                property_limit_override: nil,
                team_limit_override: nil,
                photo_limit_override: nil,
                app_store_subscription_active: nil,
                app_store_subscription_expires_at: nil
            )
        )

        #expect(property.ownerDisplayName == "owner")
    }

    @Test("Manager can edit but not delete property")
    func managerPermissions() {
        let property = makeProperty(propertyMembers: [.init(role: "manager")])

        #expect(property.membershipRole == "manager")
        #expect(property.canEditProperty)
        #expect(!property.canDeleteProperty)
    }

    @Test("Owner can edit and delete property")
    func ownerPermissions() {
        let property = makeProperty(propertyMembers: [.init(role: "owner")])

        #expect(property.canEditProperty)
        #expect(property.canDeleteProperty)
    }

    @Test("Maintainer cannot edit or delete property")
    func maintainerPermissions() {
        let property = makeProperty(propertyMembers: [.init(role: "maintainer")])

        #expect(!property.canEditProperty)
        #expect(!property.canDeleteProperty)
    }

    @Test("Owner profile subscription inherits pro from active App Store billing")
    func ownerTierReflectsSyncedBilling() {
        let owner = PropertyModel.OwnerProfile(
            subscription_tier: "free",
            full_name: nil,
            email: "owner@example.com",
            company_logo_url: nil,
            business_details: nil,
            property_limit_override: nil,
            team_limit_override: nil,
            photo_limit_override: nil,
            app_store_subscription_active: true,
            app_store_subscription_expires_at: futureISOString()
        )
        let property = makeProperty(owner: owner)

        #expect(property.ownerTier == "pro")
    }
}
