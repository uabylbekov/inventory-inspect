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
    let created_at: String
    let updated_at: String
    
    var hasProFeatures: Bool {
        return subscription_tier == "pro" || subscription_tier == "business" || subscription_tier == "lifetime"
    }

    var hasBusinessFeatures: Bool {
        return subscription_tier == "business" || subscription_tier == "lifetime"
    }
}
