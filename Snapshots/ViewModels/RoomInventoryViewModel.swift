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
    
    func fetchItems(showLoadingState: Bool = true) async {
        if showLoadingState {
            isLoading = true
        }
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
        } catch is CancellationError {
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { items[$0] }
        items.remove(atOffsets: offsets)
        
        Task {
            for item in itemsToDelete {
                do {
                    try await supabase
                        .from("room_inventory_items")
                        .delete()
                        .eq("id", value: item.id.uuidString.lowercased())
                        .execute()
                } catch {
                    print("Failed to delete item: \(error)")
                }
            }
        }
    }
}
