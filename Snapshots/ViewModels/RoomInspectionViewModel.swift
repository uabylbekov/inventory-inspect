import Foundation
import Supabase

@Observable
final class RoomInspectionViewModel {
    let inspection: InspectionModel
    let room: PropertyRoomModel
    
    var items: [RoomInventoryItemModel] = []
    var existingRecords: [UUID: InspectionItemModel] = [:]
    
    var isLoading = false
    var errorMessage: String?
    
    init(inspection: InspectionModel, room: PropertyRoomModel) {
        self.inspection = inspection
        self.room = room
    }
    
    func fetchData() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetchedItems: [RoomInventoryItemModel] = try await supabase
                .from("room_inventory_items")
                .select()
                .eq("room_id", value: room.id.uuidString.lowercased())
                .order("created_at", ascending: true)
                .execute()
                .value
            
            self.items = fetchedItems
            
            let fetchedRecords: [InspectionItemModel] = try await supabase
                .from("inspection_items")
                .select()
                .eq("inspection_id", value: inspection.id.uuidString.lowercased())
                .eq("room_id", value: room.id.uuidString.lowercased())
                .execute()
                .value
                
            var recordsMap: [UUID: InspectionItemModel] = [:]
            for record in fetchedRecords {
                recordsMap[record.inventory_item_id] = record
            }
            self.existingRecords = recordsMap
            
            isLoading = false
        } catch is CancellationError {
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
