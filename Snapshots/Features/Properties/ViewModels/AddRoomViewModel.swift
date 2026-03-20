import Foundation
import Supabase

@Observable @MainActor
final class AddRoomViewModel {
    let propertyId: UUID
    var name = ""
    var description = ""
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
                description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description,
                room_type: roomType
            )
            
            try await supabase.from("property_rooms")
                .insert(newRoom)
                .execute()
            
            isSaving = false
            return true
            
        } catch is CancellationError {
            self.isSaving = false
            return false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isSaving = false
            return false
        }
    }
}
