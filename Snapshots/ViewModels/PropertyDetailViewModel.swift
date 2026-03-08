import SwiftUI
import Supabase

@Observable
final class PropertyDetailViewModel {
    let property: PropertyModel
    var rooms: [PropertyRoomModel] = []
    var isLoading = false
    var errorMessage: String?
    var showingAddRoom = false
    var recentInspections: [InspectionModel] = []
    
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
    
    func fetchRecentInspections() async {
        do {
            let fetched: [InspectionModel] = try await supabase
                .from("inspections")
                .select()
                .eq("property_id", value: property.id.uuidString.lowercased())
                .order("started_at", ascending: false)
                .limit(5)
                .execute()
                .value
            self.recentInspections = fetched
        } catch {
            print("Failed to fetch recent inspections: \(error)")
        }
    }
    
    /// Returns count of inspection items for the given rooms that belong to an in-progress inspection.
    func activeInspectionItemCount(at offsets: IndexSet) async -> Int {
        let roomIds = offsets.map { rooms[$0].id.uuidString.lowercased() }
        do {
            // Find in-progress inspections for this property
            let activeInspections: [InspectionModel] = try await supabase
                .from("inspections")
                .select()
                .eq("property_id", value: property.id.uuidString.lowercased())
                .eq("status", value: "in_progress")
                .execute()
                .value
            guard !activeInspections.isEmpty else { return 0 }
            let inspectionIds = activeInspections.map { $0.id.uuidString.lowercased() }
            // Count items in those rooms belonging to active inspections
            let items: [InspectionItemModel] = try await supabase
                .from("inspection_items")
                .select()
                .in("room_id", values: roomIds)
                .in("inspection_id", values: inspectionIds)
                .execute()
                .value
            return items.count
        } catch {
            return 0
        }
    }
    
    func deleteRooms(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { rooms[$0] }
        rooms.remove(atOffsets: offsets)
        
        Task {
            for item in itemsToDelete {
                do {
                    try await supabase
                        .from("property_rooms")
                        .delete()
                        .eq("id", value: item.id.uuidString.lowercased())
                        .execute()
                } catch {
                    print("Failed to delete room: \(error)")
                }
            }
        }
    }
}
