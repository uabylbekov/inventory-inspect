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
            self.items = try await PropertyDataService.loadRoomInventoryItems(roomId: room.id)
            self.isLoading = false
        } catch is CancellationError {
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    func deleteItem(_ item: RoomInventoryItemModel) async -> Bool {
        do {
            try await PropertyDataService.deleteInventoryItem(id: item.id)
            items.removeAll { $0.id == item.id }
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = "Could not delete item. Please try again."
            return false
        }
    }

    func activeInspectionItemCount() async -> Int {
        do {
            return try await PropertyDataService.activeInspectionItemCount(
                propertyId: room.property_id,
                roomIds: [room.id]
            )
        } catch {
            return 0
        }
    }

    func deleteRoom() async -> Bool {
        do {
            try await PropertyDataService.deleteRoom(id: room.id)
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = "Could not delete room. Please try again."
            return false
        }
    }
}
