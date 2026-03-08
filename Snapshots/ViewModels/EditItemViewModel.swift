import Foundation
import Supabase

@Observable
final class EditItemViewModel {
    let item: RoomInventoryItemModel
    
    var name: String
    var description: String
    var expectedQty: Int
    
    var isSaving = false
    var errorMessage: String?
    
    init(item: RoomInventoryItemModel) {
        self.item = item
        self.name = item.name
        self.description = item.description ?? ""
        self.expectedQty = item.expected_qty
    }
    
    var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving
    }
    
    func saveToSupabase() async -> Bool {
        isSaving = true
        errorMessage = nil
        
        do {
            var params: [String: AnyJSON] = [
                "name": .string(name),
                "expected_qty": .integer(expectedQty)
            ]
            
            params["description"] = description.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(description)
            
            try await supabase
                .from("room_inventory_items")
                .update(params)
                .eq("id", value: item.id.uuidString.lowercased())
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
