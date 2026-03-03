import Foundation

// MARK: - Insert Models (Used for creating new records)

struct PropertyInsert: Codable {
    let owner_id: UUID
    let name: String
    var slug: String?
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
    var room_type: String?
}

struct RoomInventoryItemInsert: Codable {
    let room_id: UUID
    let name: String
    var expected_qty: Int = 1
}

// MARK: - Select Models (Used for fetching records)

struct PropertyModel: Codable, Identifiable, Hashable {
    let id: UUID
    let owner_id: UUID
    let name: String
    let property_type: String
    let country: String
    let address_line1: String?
    let bedrooms_count: Int
    let bathrooms_count: Double
    let created_at: String
    var property_members: [PropertyMemberModel]?
}

struct PropertyMemberModel: Codable, Hashable {
    let role: String
}

struct PropertyRoomModel: Codable, Identifiable, Hashable {
    let id: UUID
    let property_id: UUID
    let name: String
    let room_type: String?
    let sort_order: Int
    let created_at: String
}

struct RoomInventoryItemModel: Codable, Identifiable, Hashable {
    let id: UUID
    let room_id: UUID
    let name: String
    let expected_qty: Int
    let created_at: String
}
