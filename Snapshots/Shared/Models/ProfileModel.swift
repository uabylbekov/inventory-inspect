import Foundation

struct ProfileModel: Codable, Identifiable {
    let id: UUID
    let email: String
    var full_name: String?
    var subscription_tier: String
    var company_logo_url: String?
    var business_details: String?
    var property_limit_override: Int?
    var team_limit_override: Int?
    var photo_limit_override: Int?
    var app_store_original_transaction_id: String?
    var app_store_product_id: String?
    var app_store_subscription_active: Bool?
    var app_store_subscription_expires_at: String?
    var app_store_environment: String?
    var app_store_last_synced_at: String?
    let created_at: String
    let updated_at: String

    var effectiveSubscriptionTier: String {
        if subscription_tier == "business" || subscription_tier == "lifetime" {
            return subscription_tier
        }
        if subscription_tier == "pro" || hasActiveSyncedAppStoreSubscription {
            return "pro"
        }
        return "free"
    }
    
    var hasProFeatures: Bool {
        return effectiveSubscriptionTier == "pro"
            || effectiveSubscriptionTier == "business"
            || effectiveSubscriptionTier == "lifetime"
    }

    var hasBusinessFeatures: Bool {
        return effectiveSubscriptionTier == "business" || effectiveSubscriptionTier == "lifetime"
    }

    private var hasActiveSyncedAppStoreSubscription: Bool {
        guard app_store_subscription_active ?? false else { return false }
        guard let app_store_subscription_expires_at else { return true }
        guard let expirationDate = BillingDateParser.parse(app_store_subscription_expires_at) else { return false }
        return expirationDate > Date()
    }
}

enum BillingDateParser {
    private static let formatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]

        return [withFractional, withoutFractional]
    }()

    static func parse(_ value: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
