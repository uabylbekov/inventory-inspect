import Foundation

struct ProfileModel: Codable, Identifiable {
    let id: UUID
    let email: String
    var full_name: String?
    var subscription_tier: String
    var company_logo_url: String?
    var business_details: String?
    let created_at: String
    let updated_at: String
    
    var isPro: Bool {
        return subscription_tier == "pro" || subscription_tier == "enterprise" || subscription_tier == "lifetime"
    }
    
    var isEnterprise: Bool {
        return subscription_tier == "enterprise" || subscription_tier == "lifetime"
    }
}
