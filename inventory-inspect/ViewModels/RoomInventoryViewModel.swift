import SwiftUI
import Supabase

@Observable
final class RoomInventoryViewModel {
    let room: PropertyRoomModel
    var items: [RoomInventoryItemModel] = []
    var isLoading = false
    var errorMessage: String?
    var showingAddItem = false
    
    init(room: PropertyRoomModel) {
        self.room = room
    }
    
    func fetchItems() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedItems: [RoomInventoryItemModel] = try await supabase
                .from("room_inventory_items")
                .select()
                .eq("room_id", value: room.id)
                .order("created_at", ascending: false)
                .execute()
                .value
                
            self.items = fetchedItems
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}
