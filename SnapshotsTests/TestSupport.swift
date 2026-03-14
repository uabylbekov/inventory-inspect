import Foundation
@testable import Snapshots

func makeProfile(
    subscriptionTier: String,
    appStoreSubscriptionActive: Bool? = nil,
    appStoreSubscriptionExpiresAt: String? = nil
) -> ProfileModel {
    ProfileModel(
        id: UUID(),
        email: "user@example.com",
        full_name: "Test User",
        subscription_tier: subscriptionTier,
        company_logo_url: nil,
        business_details: nil,
        property_limit_override: nil,
        team_limit_override: nil,
        photo_limit_override: nil,
        app_store_original_transaction_id: nil,
        app_store_product_id: nil,
        app_store_subscription_active: appStoreSubscriptionActive,
        app_store_subscription_expires_at: appStoreSubscriptionExpiresAt,
        app_store_environment: nil,
        app_store_last_synced_at: nil,
        created_at: "2026-03-13T00:00:00Z",
        updated_at: "2026-03-13T00:00:00Z"
    )
}

func makeProperty(
    propertyMembers: [PropertyMemberModel]? = nil,
    owner: PropertyModel.OwnerProfile? = nil
) -> PropertyModel {
    PropertyModel(
        id: UUID(),
        owner_id: UUID(),
        name: "Demo Property",
        description: nil,
        property_type: "Apartment",
        country: "United States",
        address_line1: nil,
        bedrooms_count: 2,
        bathrooms_count: 1.5,
        created_at: "2026-03-13T00:00:00Z",
        property_members: propertyMembers,
        owner: owner
    )
}

func makeInspection(
    status: String = "in_progress",
    startedAt: String = "2026-03-13T00:00:00Z",
    completedAt: String? = nil
) -> InspectionModel {
    InspectionModel(
        id: UUID(),
        property_id: UUID(),
        inspector_id: UUID(),
        inspection_type: "routine",
        status: status,
        notes: nil,
        started_at: startedAt,
        completed_at: completedAt,
        cancellation_reason: nil
    )
}

func makeRoom(name: String) -> PropertyRoomModel {
    PropertyRoomModel(
        id: UUID(),
        property_id: UUID(),
        name: name,
        description: nil,
        room_type: nil,
        sort_order: 0,
        created_at: "2026-03-13T00:00:00Z"
    )
}

func makeInventoryItem(roomId: UUID, name: String) -> RoomInventoryItemModel {
    RoomInventoryItemModel(
        id: UUID(),
        room_id: roomId,
        name: name,
        description: nil,
        expected_qty: 1,
        created_at: "2026-03-13T00:00:00Z"
    )
}

func makeInspectionItem(inspectionId: UUID, roomId: UUID, inventoryItemId: UUID) -> InspectionItemModel {
    InspectionItemModel(
        id: UUID(),
        inspection_id: inspectionId,
        room_id: roomId,
        inventory_item_id: inventoryItemId,
        status: "present",
        previous_status: nil,
        notes: nil,
        image_url: nil,
        updated_at: "2026-03-13T00:00:00Z"
    )
}

func futureISOString() -> String {
    ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
}

func pastISOString() -> String {
    ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
}

func matches(_ value: String, pattern: String) -> Bool {
    value.range(of: pattern, options: .regularExpression) != nil
}
