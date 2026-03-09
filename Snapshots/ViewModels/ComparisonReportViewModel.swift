import Foundation
import Supabase
import SwiftUI

@Observable @MainActor
final class ComparisonReportViewModel {
    let older: InspectionModel
    let newer: InspectionModel
    
    var property: PropertyModel?
    var inspectorName: String?
    var anomalies: [ReportItem] = [] // for Newer inspection
    var presentItems: [ReportItem] = [] // for Newer inspection
    var changedItems: [DiffItem] = []
    var unchangedItems: [DiffItem] = []
    
    var isLoading = false
    var errorMessage: String?
    
    init(base: InspectionModel, current: InspectionModel) {
        // Automatically determine chronological order
        let date1 = AppFormatter.parseDate(base.started_at) ?? Date.distantPast
        let date2 = AppFormatter.parseDate(current.started_at) ?? Date.distantPast
        
        if date1 <= date2 {
            self.older = base
            self.newer = current
        } else {
            self.older = current
            self.newer = base
        }
    }
    
    func fetchComparison() async {
        isLoading = true
        errorMessage = nil
        do {
            // 1. Fetch Property
            let fetchedProps: [PropertyModel] = try await supabase
                .from("properties")
                .select()
                .eq("id", value: newer.property_id.uuidString.lowercased())
                .execute()
                .value
            self.property = fetchedProps.first

            // 2. Fetch Rooms
            let fetchedRooms: [PropertyRoomModel] = try await supabase
                .from("property_rooms")
                .select()
                .eq("property_id", value: older.property_id.uuidString.lowercased())
                .order("sort_order", ascending: true)
                .execute()
                .value
            
            let roomsDict = Dictionary(uniqueKeysWithValues: fetchedRooms.map { ($0.id, $0) })
            
            // 3. Batch fetch all Inventory Items for these rooms
            let allInventory: [RoomInventoryItemModel]
            if !fetchedRooms.isEmpty {
                let roomIds = fetchedRooms.map { $0.id.uuidString.lowercased() }
                allInventory = try await supabase
                    .from("room_inventory_items")
                    .select()
                    .in("room_id", values: roomIds)
                    .execute()
                    .value
            } else {
                allInventory = []
            }
            
            // Fetch OLD items
            let oldRecords: [InspectionItemModel] = try await supabase
                .from("inspection_items")
                .select()
                .eq("inspection_id", value: older.id.uuidString.lowercased())
                .execute()
                .value
            let oldDict = Dictionary(uniqueKeysWithValues: oldRecords.map { ($0.inventory_item_id, $0) })
            
            // Fetch NEW items
            let newRecords: [InspectionItemModel] = try await supabase
                .from("inspection_items")
                .select()
                .eq("inspection_id", value: newer.id.uuidString.lowercased())
                .execute()
                .value
            let newDict = Dictionary(uniqueKeysWithValues: newRecords.map { ($0.inventory_item_id, $0) })
            
            var changes: [DiffItem] = []
            var unchanged: [DiffItem] = []
            var builtAnomalies: [ReportItem] = []
            var builtPresent: [ReportItem] = []
            
            for item in allInventory {
                let oldR = oldDict[item.id]
                let newR = newDict[item.id]
                
                // If neither recorded it, skip
                if oldR == nil && newR == nil { continue }
                
                // Build ReportItems for the NEWER inspection
                if let newRecord = newR, let roomInfo = roomsDict[item.room_id] {
                    let reportItem = ReportItem(inspectionItem: newRecord, inventoryItem: item, room: roomInfo)
                    if newRecord.status == "missing" || newRecord.status == "damaged" {
                        builtAnomalies.append(reportItem)
                    } else if newRecord.status == "present" {
                        builtPresent.append(reportItem)
                    }
                }

                let oldStatus = oldR?.status ?? "Pending"
                let newStatus = newR?.status ?? "Pending"
                
                let diff = DiffItem(
                    inventoryItemId: item.id,
                    itemName: item.name,
                    roomName: roomsDict[item.room_id]?.name ?? "Unknown Room",
                    oldStatus: oldStatus,
                    oldNotes: oldR?.notes,
                    oldImage: oldR?.image_url,
                    newStatus: newStatus,
                    newNotes: newR?.notes,
                    newImage: newR?.image_url
                )
                
                if oldStatus != newStatus {
                    changes.append(diff)
                } else {
                    unchanged.append(diff)
                }
            }
            
            // Sort
            self.changedItems = changes.sorted { $0.roomName == $1.roomName ? $0.itemName < $1.itemName : $0.roomName < $1.roomName }
            self.unchangedItems = unchanged.sorted { $0.roomName == $1.roomName ? $0.itemName < $1.itemName : $0.roomName < $1.roomName }
            
            self.anomalies = builtAnomalies.sorted(by: { $0.room.name < $1.room.name })
            self.presentItems = builtPresent.sorted(by: { $0.room.name < $1.room.name })

            // 6. Fetch inspector name/email
            let params: [String: AnyJSON] = [
                "p_property_id": .string(newer.property_id.uuidString.lowercased())
            ]
            if let fetchedMembers: [TeamMemberModel] = try? await supabase
                .rpc("get_property_team_members", params: params)
                .execute()
                .value {
                if let member = fetchedMembers.first(where: { $0.user_id == newer.inspector_id }) {
                    self.inspectorName = member.name ?? member.email
                }
            }
            
            isLoading = false
        } catch is CancellationError {
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
