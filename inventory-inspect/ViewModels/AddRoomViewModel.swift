import Foundation
import Supabase

@Observable
final class AddRoomViewModel {
    let propertyId: UUID
    var name = ""
    var roomType = "Bedroom"
    var isSaving = false
    var errorMessage: String?
    
    init(propertyId: UUID) {
        self.propertyId = propertyId
    }
    
    var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving
    }
    
    func saveToSupabase() async -> Bool {
        isSaving = true
        errorMessage = nil
        
        do {
            let newRoom = PropertyRoomInsert(
                property_id: propertyId,
                name: name,
                room_type: roomType
            )
            
            try await supabase.from("property_rooms")
                .insert(newRoom)
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
