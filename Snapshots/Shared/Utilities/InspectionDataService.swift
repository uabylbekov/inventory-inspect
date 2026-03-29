import Foundation
import Supabase

struct InspectionReportSnapshot {
    let property: PropertyModel?
    let inspectorName: String?
    let anomalies: [ReportItem]
    let presentItems: [ReportItem]
    let resolvedItems: [ReportItem]
}

struct InspectionHubSnapshot {
    let property: PropertyModel?
    let rooms: [PropertyRoomModel]
    let inventoryItems: [RoomInventoryItemModel]
    let inspectionItems: [InspectionItemModel]
}

struct RoomInspectionSnapshot {
    let items: [RoomInventoryItemModel]
    let existingRecords: [UUID: InspectionItemModel]
}

struct ComparisonReportSnapshot {
    let property: PropertyModel?
    let previousInspectorName: String?
    let currentInspectorName: String?
    let anomalies: [ReportItem]
    let presentItems: [ReportItem]
    let changedItems: [DiffItem]
    let unchangedItems: [DiffItem]
}

struct InspectionDataService {
    static func loadAccessibleInspections(for userId: UUID) async throws -> [InspectionModel] {
        let properties = try await PropertyAccessService.loadAccessibleProperties(for: userId)
        guard !properties.isEmpty else { return [] }

        let propertyIds = properties.map { $0.id.uuidString.lowercased() }
        return try await supabase
            .from("inspections")
            .select()
            .in("property_id", values: propertyIds)
            .order("started_at", ascending: false)
            .execute()
            .value
    }

    static func loadCompletedInspections(for propertyId: UUID, excluding inspectionId: UUID) async throws -> [InspectionModel] {
        try await supabase
            .from("inspections")
            .select()
            .eq("property_id", value: propertyId.uuidString.lowercased())
            .eq("status", value: "completed")
            .neq("id", value: inspectionId.uuidString.lowercased())
            .order("completed_at", ascending: false)
            .limit(3)
            .execute()
            .value
    }

    static func loadReportSnapshot(for inspection: InspectionModel) async throws -> InspectionReportSnapshot {
        let context = try await loadInspectionContext(propertyId: inspection.property_id)
        let inspectionItems: [InspectionItemModel] = try await supabase
            .from("inspection_items")
            .select()
            .eq("inspection_id", value: inspection.id.uuidString.lowercased())
            .execute()
            .value

        let classified = classifyReportItems(
            inspectionItems: inspectionItems,
            rooms: context.roomsById,
            inventory: context.inventoryById
        )

        return InspectionReportSnapshot(
            property: context.property,
            inspectorName: await fetchInspectorName(
                propertyId: inspection.property_id,
                inspectorId: inspection.inspector_id
            ),
            anomalies: classified.anomalies,
            presentItems: classified.presentItems,
            resolvedItems: classified.resolvedItems
        )
    }

    static func loadInspectionHubSnapshot(for inspection: InspectionModel) async throws -> InspectionHubSnapshot {
        let context = try await loadInspectionContext(propertyId: inspection.property_id)
        let inspectionItems: [InspectionItemModel] = try await supabase
            .from("inspection_items")
            .select()
            .eq("inspection_id", value: inspection.id.uuidString.lowercased())
            .execute()
            .value

        return InspectionHubSnapshot(
            property: context.property,
            rooms: context.rooms,
            inventoryItems: context.inventoryItems,
            inspectionItems: inspectionItems
        )
    }

    static func loadRoomInspectionSnapshot(inspectionId: UUID, roomId: UUID) async throws -> RoomInspectionSnapshot {
        let items: [RoomInventoryItemModel] = try await supabase
            .from("room_inventory_items")
            .select()
            .eq("room_id", value: roomId.uuidString.lowercased())
            .order("created_at", ascending: true)
            .execute()
            .value

        let records: [InspectionItemModel] = try await supabase
            .from("inspection_items")
            .select()
            .eq("inspection_id", value: inspectionId.uuidString.lowercased())
            .eq("room_id", value: roomId.uuidString.lowercased())
            .execute()
            .value

        return RoomInspectionSnapshot(
            items: items,
            existingRecords: Dictionary(uniqueKeysWithValues: records.map { ($0.inventory_item_id, $0) })
        )
    }

    static func loadInventoryHistory(for inventoryItemId: UUID) async throws -> [InspectionItemModel] {
        try await supabase
            .from("inspection_items")
            .select()
            .eq("inventory_item_id", value: inventoryItemId.uuidString.lowercased())
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    static func loadComparisonSnapshot(older: InspectionModel, newer: InspectionModel) async throws -> ComparisonReportSnapshot {
        let context = try await loadInspectionContext(propertyId: newer.property_id)
        async let previousInspectorName = fetchInspectorName(
            propertyId: older.property_id,
            inspectorId: older.inspector_id
        )
        async let currentInspectorName = fetchInspectorName(
            propertyId: newer.property_id,
            inspectorId: newer.inspector_id
        )

        let oldRecords: [InspectionItemModel] = try await supabase
            .from("inspection_items")
            .select()
            .eq("inspection_id", value: older.id.uuidString.lowercased())
            .execute()
            .value
        let newRecords: [InspectionItemModel] = try await supabase
            .from("inspection_items")
            .select()
            .eq("inspection_id", value: newer.id.uuidString.lowercased())
            .execute()
            .value

        let oldByInventoryId = Dictionary(uniqueKeysWithValues: oldRecords.map { ($0.inventory_item_id, $0) })
        let newByInventoryId = Dictionary(uniqueKeysWithValues: newRecords.map { ($0.inventory_item_id, $0) })

        var changes: [DiffItem] = []
        var unchanged: [DiffItem] = []
        var anomalies: [ReportItem] = []
        var presentItems: [ReportItem] = []

        for item in context.inventoryItems {
            let oldRecord = oldByInventoryId[item.id]
            let newRecord = newByInventoryId[item.id]

            if oldRecord == nil && newRecord == nil {
                continue
            }

            if let newRecord, let room = context.roomsById[item.room_id] {
                let reportItem = ReportItem(inspectionItem: newRecord, inventoryItem: item, room: room)
                if newRecord.status == "missing" || newRecord.status == "damaged" {
                    anomalies.append(reportItem)
                } else if newRecord.status == "present" {
                    presentItems.append(reportItem)
                }
            }

            let oldStatus = oldRecord?.status ?? "Pending"
            let newStatus = newRecord?.status ?? "Pending"
            let diff = DiffItem(
                inventoryItemId: item.id,
                itemName: item.name,
                roomName: context.roomsById[item.room_id]?.name ?? "Unknown Room",
                oldStatus: oldStatus,
                oldNotes: oldRecord?.notes,
                oldImage: oldRecord?.image_url,
                newStatus: newStatus,
                newPreviousStatus: newRecord?.previous_status,
                newNotes: newRecord?.notes,
                newImage: newRecord?.image_url
            )

            if oldStatus != newStatus {
                changes.append(diff)
            } else {
                unchanged.append(diff)
            }
        }

        return ComparisonReportSnapshot(
            property: context.property,
            previousInspectorName: await previousInspectorName,
            currentInspectorName: await currentInspectorName,
            anomalies: anomalies.sorted(by: { $0.room.name < $1.room.name }),
            presentItems: presentItems.sorted(by: { $0.room.name < $1.room.name }),
            changedItems: changes.sorted { $0.roomName == $1.roomName ? $0.itemName < $1.itemName : $0.roomName < $1.roomName },
            unchangedItems: unchanged.sorted { $0.roomName == $1.roomName ? $0.itemName < $1.itemName : $0.roomName < $1.roomName }
        )
    }

    private struct InspectionContext {
        let property: PropertyModel?
        let rooms: [PropertyRoomModel]
        let roomsById: [UUID: PropertyRoomModel]
        let inventoryById: [UUID: RoomInventoryItemModel]
        let inventoryItems: [RoomInventoryItemModel]
    }

    private static func loadInspectionContext(propertyId: UUID) async throws -> InspectionContext {
        let fetchedProperties: [PropertyModel] = try await supabase
            .from("properties")
            .select()
            .eq("id", value: propertyId.uuidString.lowercased())
            .execute()
            .value
        let property = try await PropertyOwnerProfileLoader.enrich(fetchedProperties).first

        let rooms: [PropertyRoomModel] = try await supabase
            .from("property_rooms")
            .select()
            .eq("property_id", value: propertyId.uuidString.lowercased())
            .order("sort_order", ascending: true)
            .execute()
            .value

        let inventoryItems: [RoomInventoryItemModel]
        if rooms.isEmpty {
            inventoryItems = []
        } else {
            let roomIds = rooms.map { $0.id.uuidString.lowercased() }
            inventoryItems = try await supabase
                .from("room_inventory_items")
                .select()
                .in("room_id", values: roomIds)
                .execute()
                .value
        }

        return InspectionContext(
            property: property,
            rooms: rooms,
            roomsById: Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, $0) }),
            inventoryById: Dictionary(uniqueKeysWithValues: inventoryItems.map { ($0.id, $0) }),
            inventoryItems: inventoryItems
        )
    }

    private static func classifyReportItems(
        inspectionItems: [InspectionItemModel],
        rooms: [UUID: PropertyRoomModel],
        inventory: [UUID: RoomInventoryItemModel]
    ) -> (anomalies: [ReportItem], presentItems: [ReportItem], resolvedItems: [ReportItem]) {
        var anomalies: [ReportItem] = []
        var presentItems: [ReportItem] = []
        var resolvedItems: [ReportItem] = []

        for itemRecord in inspectionItems {
            guard let room = rooms[itemRecord.room_id],
                  let inventoryItem = inventory[itemRecord.inventory_item_id] else { continue }

            let reportItem = ReportItem(inspectionItem: itemRecord, inventoryItem: inventoryItem, room: room)

            if itemRecord.status == "missing" || itemRecord.status == "damaged" {
                anomalies.append(reportItem)
            } else if itemRecord.status == "resolved" {
                resolvedItems.append(reportItem)
            } else if itemRecord.status == "present" {
                presentItems.append(reportItem)
            }
        }

        return (
            anomalies.sorted(by: { $0.room.name < $1.room.name }),
            presentItems.sorted(by: { $0.room.name < $1.room.name }),
            resolvedItems.sorted(by: { $0.room.name < $1.room.name })
        )
    }

    private static func fetchInspectorName(propertyId: UUID, inspectorId: UUID) async -> String? {
        let params: [String: AnyJSON] = [
            "p_property_id": .string(propertyId.uuidString.lowercased())
        ]

        guard let members: [TeamMemberModel] = try? await supabase
            .rpc("get_property_team_members", params: params)
            .execute()
            .value else {
            return nil
        }

        return members.first(where: { $0.user_id == inspectorId }).map { $0.name ?? $0.email }
    }
}
