import Foundation

// MARK: - Insert Models (Used for creating new records)

struct PropertyInsert: Codable {
    let owner_id: UUID
    let name: String
    var description: String?
    let property_type: String
    var status: String = "active"
    let country: String
    var state_region: String?
    var city: String?
    var address_line1: String?
    var address_line2: String?
    var postal_code: String?
    var latitude: Double?
    var longitude: Double?
    var bedrooms_count: Int = 1
    var bathrooms_count: Double = 1.0
    var max_guests: Int?
    var airbnb_listing_id: String?
    var vrbo_listing_id: String?
}

struct PropertyRoomInsert: Codable {
    let property_id: UUID
    let name: String
    var description: String?
    var room_type: String?
}

struct RoomInventoryItemInsert: Codable {
    let room_id: UUID
    let name: String
    var description: String?
    var expected_qty: Int = 1
}

// MARK: - Select Models (Used for fetching records)

struct PropertyModel: Codable, Identifiable, Hashable {
    let id: UUID
    let owner_id: UUID
    let name: String
    let description: String?
    let property_type: String
    let country: String
    let address_line1: String?
    let bedrooms_count: Int
    let bathrooms_count: Double
    let created_at: String
    var property_members: [PropertyMemberModel]?
    
    // Joint data for subscription inheritance
    struct OwnerProfile: Codable, Hashable {
        let subscription_tier: String
        let full_name: String?
        let email: String?
        let company_logo_url: String?
        let property_limit_override: Int?
        let team_limit_override: Int?
        let photo_limit_override: Int?
        let app_store_subscription_active: Bool?
        let app_store_subscription_expires_at: String?

        var effectiveSubscriptionTier: String {
            if subscription_tier == "business" || subscription_tier == "lifetime" {
                return subscription_tier
            }
            if subscription_tier == "pro" {
                return "pro"
            }
            guard app_store_subscription_active ?? false else { return "free" }
            guard let app_store_subscription_expires_at else { return "pro" }
            guard let expirationDate = BillingDateParser.parse(app_store_subscription_expires_at) else { return "free" }
            return expirationDate > Date() ? "pro" : "free"
        }
    }
    let owner: OwnerProfile?
    
    var ownerTier: String {
        owner?.effectiveSubscriptionTier ?? "free"
    }

    var ownerDisplayName: String {
        if let name = owner?.full_name, !name.isEmpty { return name }
        if let email = owner?.email { return email.components(separatedBy: "@").first ?? email }
        return "Owner"
    }

    init(
        id: UUID,
        owner_id: UUID,
        name: String,
        description: String?,
        property_type: String,
        country: String,
        address_line1: String?,
        bedrooms_count: Int,
        bathrooms_count: Double,
        created_at: String,
        property_members: [PropertyMemberModel]?,
        owner: OwnerProfile?
    ) {
        self.id = id
        self.owner_id = owner_id
        self.name = name
        self.description = description
        self.property_type = property_type
        self.country = country
        self.address_line1 = address_line1
        self.bedrooms_count = bedrooms_count
        self.bathrooms_count = bathrooms_count
        self.created_at = created_at
        self.property_members = property_members
        self.owner = owner
    }
}

struct PropertyMemberModel: Codable, Hashable {
    let role: String
}

struct PropertyRoomModel: Codable, Identifiable, Hashable {
    let id: UUID
    let property_id: UUID
    let name: String
    let description: String?
    let room_type: String?
    let sort_order: Int
    let created_at: String
}

struct TeamMemberModel: Codable, Identifiable, Hashable {
    let id: UUID
    let user_id: UUID
    let email: String
    let name: String?
    let role: String
}

struct RoomInventoryItemModel: Codable, Identifiable, Hashable {
    let id: UUID
    let room_id: UUID
    let name: String
    let description: String?
    let expected_qty: Int
    let created_at: String
}

// MARK: - Inspection Models

struct InspectionInsert: Codable {
    let property_id: UUID
    let inspector_id: UUID
    let inspection_type: String
    var status: String = "in_progress"
    var notes: String?
}

struct InspectionItemInsert: Codable {
    let inspection_id: UUID
    let room_id: UUID
    let inventory_item_id: UUID
    var status: String = "present"
    var notes: String?
    var image_url: String?
}

struct InspectionModel: Codable, Identifiable, Hashable {
    let id: UUID
    let property_id: UUID
    let inspector_id: UUID
    let inspection_type: String
    var status: String
    let notes: String?
    let started_at: String
    let completed_at: String?
    let cancellation_reason: String?
}

struct InspectionItemModel: Codable, Identifiable, Hashable {
    let id: UUID
    let inspection_id: UUID
    let room_id: UUID
    let inventory_item_id: UUID
    let status: String
    let previous_status: String?
    let notes: String?
    let image_url: String?
    let updated_at: String
}
