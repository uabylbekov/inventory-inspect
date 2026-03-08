import Foundation
import Supabase

@Observable
final class EditRoomViewModel {
    let room: PropertyRoomModel
    
    var name: String
    var description: String
    var roomType: String
    
    var isSaving = false
    var errorMessage: String?
    
    init(room: PropertyRoomModel) {
        self.room = room
        self.name = room.name
        self.description = room.description ?? ""
        self.roomType = room.room_type ?? "Bedroom"
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
                "room_type": .string(roomType)
            ]
            
            params["description"] = description.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(description)
            
            try await supabase
                .from("property_rooms")
                .update(params)
                .eq("id", value: room.id.uuidString.lowercased())
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
