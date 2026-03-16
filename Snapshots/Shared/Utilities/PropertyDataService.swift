import Foundation
import Supabase

struct PropertyDetailSnapshot {
    let rooms: [PropertyRoomModel]
    let recentInspections: [InspectionModel]
}

enum PropertyDataService {
    static func loadProperty(id: UUID) async throws -> PropertyModel {
        let session = try await supabase.auth.session

        if let accessibleProperty = try await PropertyAccessService
            .loadAccessibleProperties(for: session.user.id)
            .first(where: { $0.id == id }) {
            return accessibleProperty
        }

        throw NSError(
            domain: "PropertyDataService",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Property not found or you no longer have access to it."]
        )
    }

    static func loadPropertyDetailSnapshot(propertyId: UUID) async throws -> PropertyDetailSnapshot {
        async let roomsTask = loadRooms(propertyId: propertyId)
        async let inspectionsTask = loadRecentInspections(propertyId: propertyId)
        let rooms = try await roomsTask
        let inspections = try await inspectionsTask
        return PropertyDetailSnapshot(
            rooms: rooms,
            recentInspections: inspections
        )
    }

    static func loadRooms(propertyId: UUID) async throws -> [PropertyRoomModel] {
        try await supabase
            .from("property_rooms")
            .select()
            .eq("property_id", value: propertyId.uuidString.lowercased())
            .order("sort_order", ascending: true)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func loadRecentInspections(propertyId: UUID, limit: Int = 5) async throws -> [InspectionModel] {
        try await supabase
            .from("inspections")
            .select()
            .eq("property_id", value: propertyId.uuidString.lowercased())
            .order("started_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func activeInspectionItemCount(propertyId: UUID, roomIds: [UUID]) async throws -> Int {
        guard !roomIds.isEmpty else { return 0 }

        let activeInspections: [InspectionModel] = try await supabase
            .from("inspections")
            .select()
            .eq("property_id", value: propertyId.uuidString.lowercased())
            .eq("status", value: "in_progress")
            .execute()
            .value

        guard !activeInspections.isEmpty else { return 0 }

        let items: [InspectionItemModel] = try await supabase
            .from("inspection_items")
            .select()
            .in("room_id", values: roomIds.map { $0.uuidString.lowercased() })
            .in("inspection_id", values: activeInspections.map { $0.id.uuidString.lowercased() })
            .execute()
            .value
        return items.count
    }

    static func activeInspectionCount(propertyId: UUID) async throws -> Int {
        let inspections: [InspectionModel] = try await supabase
            .from("inspections")
            .select()
            .eq("property_id", value: propertyId.uuidString.lowercased())
            .eq("status", value: "in_progress")
            .execute()
            .value
        return inspections.count
    }

    static func deleteProperty(id: UUID) async throws {
        try await supabase
            .from("properties")
            .delete()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }

    static func loadRoom(id: UUID) async throws -> PropertyRoomModel {
        try await supabase
            .from("property_rooms")
            .select()
            .eq("id", value: id.uuidString.lowercased())
            .single()
            .execute()
            .value
    }

    static func deleteRoom(id: UUID) async throws {
        try await supabase
            .from("property_rooms")
            .delete()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }

    static func loadRoomInventoryItems(roomId: UUID) async throws -> [RoomInventoryItemModel] {
        try await supabase
            .from("room_inventory_items")
            .select()
            .eq("room_id", value: roomId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func loadInventoryItem(id: UUID) async throws -> RoomInventoryItemModel {
        try await supabase
            .from("room_inventory_items")
            .select()
            .eq("id", value: id.uuidString.lowercased())
            .single()
            .execute()
            .value
    }

    static func deleteInventoryItem(id: UUID) async throws {
        try await supabase
            .from("room_inventory_items")
            .delete()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }
}
