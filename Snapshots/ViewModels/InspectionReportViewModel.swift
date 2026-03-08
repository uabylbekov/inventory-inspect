import Foundation
import Supabase
import SwiftUI

struct ReportItem: Identifiable {
    var id: UUID { inspectionItem.id }
    let inspectionItem: InspectionItemModel
    let inventoryItem: RoomInventoryItemModel
    let room: PropertyRoomModel
}

@Observable
final class InspectionReportViewModel {
    let inspection: InspectionModel
    
    var property: PropertyModel?
    var inspectorName: String?
    var anomalies: [ReportItem] = [] // missing or damaged
    var presentItems: [ReportItem] = []
    var resolvedItems: [ReportItem] = [] // fixed issues
    
    var isLoading = false
    var errorMessage: String?
    
    init(inspection: InspectionModel) {
        self.inspection = inspection
    }
    
    func fetchReportData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Fetch the Property
            let fetchedProperties: [PropertyModel] = try await supabase
                .from("properties")
                .select()
                .eq("id", value: inspection.property_id.uuidString.lowercased())
                .execute()
                .value
            
            self.property = fetchedProperties.first
            
            // 2. Fetch all Rooms for Property
            let fetchedRooms: [PropertyRoomModel] = try await supabase
                .from("property_rooms")
                .select()
                .eq("property_id", value: inspection.property_id.uuidString.lowercased())
                .execute()
                .value
                
            let roomsDict = Dictionary(uniqueKeysWithValues: fetchedRooms.map { ($0.id, $0) })
            
            // 3. Fetch all Inventory Items for these rooms
            // Limit to just those rooms in chunks if >100, but in our case property_rooms is small enough
            // Instead, we just fetch all items and filter below. (Optimal way is matching room_id IN (...))
            var fetchedInventoryItems: [RoomInventoryItemModel] = []
            for room in fetchedRooms {
                let items: [RoomInventoryItemModel] = try await supabase
                    .from("room_inventory_items")
                    .select()
                    .eq("room_id", value: room.id.uuidString.lowercased())
                    .execute()
                    .value
                fetchedInventoryItems.append(contentsOf: items)
            }
            let inventoryDict = Dictionary(uniqueKeysWithValues: fetchedInventoryItems.map { ($0.id, $0) })
            
            // 4. Fetch the Inspection Items for this specific inspection
            let fetchedInspectionItems: [InspectionItemModel] = try await supabase
                .from("inspection_items")
                .select()
                .eq("inspection_id", value: inspection.id.uuidString.lowercased())
                .execute()
                .value
            
            // 5. Construct the Report Items
            var builtAnomalies: [ReportItem] = []
            var builtPresent: [ReportItem] = []
            var builtResolved: [ReportItem] = []
            
            for itemRecord in fetchedInspectionItems {
                guard let roomInfo = roomsDict[itemRecord.room_id],
                      let inventoryInfo = inventoryDict[itemRecord.inventory_item_id] else { continue }
                
                let reportItem = ReportItem(inspectionItem: itemRecord, inventoryItem: inventoryInfo, room: roomInfo)
                
                if itemRecord.status == "missing" || itemRecord.status == "damaged" {
                    builtAnomalies.append(reportItem)
                } else if itemRecord.status == "resolved" {
                    builtResolved.append(reportItem)
                } else if itemRecord.status == "present" {
                    builtPresent.append(reportItem)
                }
            }
            
            self.anomalies = builtAnomalies.sorted(by: { $0.room.name < $1.room.name })
            self.presentItems = builtPresent.sorted(by: { $0.room.name < $1.room.name })
            self.resolvedItems = builtResolved.sorted(by: { $0.room.name < $1.room.name })
            
            // 6. Fetch inspector name/email from property team members
            let params: [String: AnyJSON] = [
                "p_property_id": .string(inspection.property_id.uuidString.lowercased())
            ]
            if let fetchedMembers: [TeamMemberModel] = try? await supabase
                .rpc("get_property_team_members", params: params)
                .execute()
                .value {
                if let member = fetchedMembers.first(where: { $0.user_id == inspection.inspector_id }) {
                    self.inspectorName = member.name ?? member.email
                }
            }
            
            self.isLoading = false
            
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    func resolveAnomaly(reportItem: ReportItem) async {
        // Find existing index and store local copy for potential fallback
        guard let index = anomalies.firstIndex(where: { $0.id == reportItem.id }) else { return }
        let originalItem = anomalies[index]
        
        var currentName = "unknown user"
        if let user = try? await supabase.auth.session.user {
            if case let .string(fullName) = user.userMetadata["full_name"], !fullName.isEmpty {
                currentName = fullName
            } else {
                currentName = user.email ?? currentName
            }
        }
        let resolvedNotes = "Resolved by \(currentName)"
        
        // Construct resolved version
        let updatedInspectionItem = InspectionItemModel(
            id: originalItem.inspectionItem.id,
            inspection_id: originalItem.inspectionItem.inspection_id,
            room_id: originalItem.inspectionItem.room_id,
            inventory_item_id: originalItem.inspectionItem.inventory_item_id,
            status: "resolved",
            notes: resolvedNotes,
            image_url: originalItem.inspectionItem.image_url,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        let resolvedItem = ReportItem(
            inspectionItem: updatedInspectionItem,
            inventoryItem: originalItem.inventoryItem,
            room: originalItem.room
        )
        
        // 1. Optimistic Update (Immediate Feedback)
        await MainActor.run {
            withAnimation(.spring) {
                anomalies.remove(at: index)
                resolvedItems.append(resolvedItem)
                resolvedItems.sort(by: { $0.room.name < $1.room.name })
            }
        }
        
        do {
            // 2. Perform DB Update
            try await supabase
                .from("inspection_items")
                .update(["status": "resolved", "notes": resolvedNotes])
                .eq("id", value: reportItem.inspectionItem.id.uuidString.lowercased())
                .execute()
        } catch {
            print("Error resolving anomaly: \(error)")
            // 3. Fallback on Error
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                withAnimation {
                    resolvedItems.removeAll(where: { $0.id == reportItem.id })
                    anomalies.append(originalItem)
                    anomalies.sort(by: { $0.room.name < $1.room.name })
                }
            }
        }
    }
}
