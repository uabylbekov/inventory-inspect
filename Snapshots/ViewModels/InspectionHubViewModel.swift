import Foundation
import Supabase

@Observable @MainActor
final class InspectionHubViewModel {
    let inspection: InspectionModel
    
    var rooms: [PropertyRoomModel] = []
    var property: PropertyModel? = nil
    var allInventoryItems: [RoomInventoryItemModel] = []
    var inspectionItems: [InspectionItemModel] = []
    
    var roomProgressList: [RoomProgress] = []
    
    var isLoading = false
    var isCompleting = false
    var errorMessage: String?
    
    private var channel: RealtimeChannelV2?
    
    init(inspection: InspectionModel) {
        self.inspection = inspection
    }
    
    func unsubscribe() {
        let ch = channel
        self.channel = nil
        if let ch {
            Task {
                await ch.unsubscribe()
            }
        }
    }
    
    struct RoomProgress: Identifiable {
        let room: PropertyRoomModel
        let totalItems: Int
        let inspectedItems: Int
        var id: UUID { room.id }
        
        var isComplete: Bool {
            totalItems > 0 && totalItems == inspectedItems
        }
        
        var progressString: String {
            if totalItems == 0 { return "Empty" }
            return "\(inspectedItems)/\(totalItems)"
        }
        
        var progressFraction: Double {
            if totalItems == 0 { return 1.0 }
            return Double(inspectedItems) / Double(totalItems)
        }
    }
    
    var allRoomsComplete: Bool {
        let totalItems = roomProgressList.reduce(0) { $0 + $1.totalItems }
        guard totalItems > 0 else { return false }  // Empty property can't be completed
        return roomProgressList.allSatisfy { $0.totalItems == 0 || $0.isComplete }
    }
    
    func fetchData() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetchedRooms: [PropertyRoomModel] = try await supabase
                .from("property_rooms")
                .select()
                .eq("property_id", value: inspection.property_id.uuidString.lowercased())
                .order("sort_order", ascending: true)
                .execute()
                .value
            
            self.rooms = fetchedRooms

            let fetchedProperty: [PropertyModel] = try await supabase
                .from("properties")
                .select()
                .eq("id", value: inspection.property_id.uuidString.lowercased())
                .execute()
                .value
            self.property = fetchedProperty.first
            
            var allItems: [RoomInventoryItemModel] = []
            for room in fetchedRooms {
                let items: [RoomInventoryItemModel] = try await supabase
                    .from("room_inventory_items")
                    .select()
                    .eq("room_id", value: room.id.uuidString.lowercased())
                    .execute()
                    .value
                allItems.append(contentsOf: items)
            }
            self.allInventoryItems = allItems
            
            let fetchedInspectionItems: [InspectionItemModel] = try await supabase
                .from("inspection_items")
                .select()
                .eq("inspection_id", value: inspection.id.uuidString.lowercased())
                .execute()
                .value
                
            self.inspectionItems = fetchedInspectionItems
            
            calculateProgress()
            isLoading = false
        } catch {
            if error is CancellationError {
                isLoading = false
            } else {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func setupRealtime() async {
        let channel = supabase.channel("inspection_updates")
        
        let observation = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "inspection_items",
            filter: .eq("inspection_id", value: inspection.id.uuidString.lowercased())
        )
        
        Task {
            for await _ in observation {
                await fetchData()
            }
        }
        
        try? await channel.subscribeWithError()
        self.channel = channel
    }
    
    func calculateProgress() {
        var progressList: [RoomProgress] = []
        let inspectionItemIds = Set(inspectionItems.map { $0.inventory_item_id })
        
        for room in rooms {
            let itemsInRoom = allInventoryItems.filter { $0.room_id == room.id }
            let total = itemsInRoom.count
            let checkedCount = itemsInRoom.filter { inspectionItemIds.contains($0.id) }.count
            progressList.append(RoomProgress(room: room, totalItems: total, inspectedItems: checkedCount))
        }
        
        self.roomProgressList = progressList
    }
    
    func roomProgress(for roomId: UUID) -> RoomProgress? {
        roomProgressList.first(where: { $0.id == roomId })
    }
    
    func inspectionRecord(for itemId: UUID) -> InspectionItemModel? {
        inspectionItems.first(where: { $0.inventory_item_id == itemId })
    }
    
    func completeInspection() async -> Bool {
        isCompleting = true
        errorMessage = nil
        do {
            let params: [String: AnyJSON] = [
                "status": .string("completed"),
                "completed_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            try await supabase
                .from("inspections")
                .update(params)
                .eq("id", value: inspection.id.uuidString.lowercased())
                .execute()
                
            isCompleting = false
            return true
        } catch is CancellationError {
            isCompleting = false
            return false
        } catch {
            errorMessage = error.localizedDescription
            isCompleting = false
            return false
        }
    }
    
    func cancelInspection(reason: String) async -> Bool {
        errorMessage = nil
        do {
            let params: [String: AnyJSON] = [
                "status": .string("cancelled"),
                "notes": .string(reason.isEmpty ? "Cancelled" : reason)
            ]
            try await supabase
                .from("inspections")
                .update(params)
                .eq("id", value: inspection.id.uuidString.lowercased())
                .execute()
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteInspection() async -> Bool {
        errorMessage = nil
        do {
            try await supabase
                .from("inspections")
                .delete()
                .eq("id", value: inspection.id.uuidString.lowercased())
                .execute()
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
