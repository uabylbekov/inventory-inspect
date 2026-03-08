import Foundation
import Supabase

@Observable
final class AddItemViewModel {
    let roomId: UUID
    var name = ""
    var description = ""
    var expectedQty = 1
    var isSaving = false
    var errorMessage: String?
    
    init(roomId: UUID) {
        self.roomId = roomId
    }
    
    var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving
    }
    
    func saveToSupabase() async -> Bool {
        isSaving = true
        errorMessage = nil
        
        do {
            let newItem = RoomInventoryItemInsert(
                room_id: roomId,
                name: name,
                description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description,
                expected_qty: expectedQty
            )
            
            try await supabase.from("room_inventory_items")
                .insert(newItem)
                .execute()
            
            isSaving = false
            return true
            
        } catch {
            self.errorMessage = error.localizedDescription
            self.isSaving = false
            return false
        }
    }
}
