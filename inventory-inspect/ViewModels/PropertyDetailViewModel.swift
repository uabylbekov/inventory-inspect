import SwiftUI
import Supabase

@Observable
final class PropertyDetailViewModel {
    let property: PropertyModel
    var rooms: [PropertyRoomModel] = []
    var isLoading = false
    var errorMessage: String?
    var showingAddRoom = false
    
    init(property: PropertyModel) {
        self.property = property
    }
    
    // Checks if the current user is an owner based on the joined property_members array
    var isOwner: Bool {
        property.property_members?.contains(where: { $0.role == "owner" }) ?? false
    }
    
    func fetchRooms() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedRooms: [PropertyRoomModel] = try await supabase
                .from("property_rooms")
                .select()
                .eq("property_id", value: property.id)
                .order("sort_order", ascending: true)
                .order("created_at", ascending: false)
                .execute()
                .value
                
            self.rooms = fetchedRooms
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}
