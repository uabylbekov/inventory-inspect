import SwiftUI
import Supabase

@Observable @MainActor
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
    
    var isOwner: Bool {
        hasRole("owner")
    }

    var isManager: Bool {
        hasRole("manager")
    }
    
    func fetchRooms() async {
        isLoading = true
        errorMessage = nil
        
        do {
            rooms = try await loadRooms()
            self.isLoading = false
        } catch is CancellationError {
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    func fetchData() async {
        async let roomsTask: Void = fetchRooms()
        async let inspectionsTask: Void = fetchRecentInspections()
        _ = await (roomsTask, inspectionsTask)
    }
    
    func fetchRecentInspections() async {
        do {
            recentInspections = try await loadRecentInspections()
        } catch {
            recentInspections = []
        }
    }
    
    /// Returns count of inspection items for the given rooms that belong to an in-progress inspection.
    func activeInspectionItemCount(at offsets: IndexSet) async -> Int {
        let roomIds = offsets.map { rooms[$0].id.uuidString.lowercased() }
        do {
            let activeInspections = try await loadActiveInspections()
            guard !activeInspections.isEmpty else { return 0 }
            let inspectionIds = activeInspections.map { $0.id.uuidString.lowercased() }

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
    
    func deleteRooms(at offsets: IndexSet) async {
        let itemsToDelete = offsets.map { rooms[$0] }
        
        for item in itemsToDelete {
            do {
                try await deleteRoom(item)
                
                if let index = rooms.firstIndex(where: { $0.id == item.id }) {
                    rooms.remove(at: index)
                }
            } catch {
                self.errorMessage = "Could not delete room. Please try again."
            }
        }
    }

    private func hasRole(_ role: String) -> Bool {
        property.property_members?.contains(where: { $0.role == role }) ?? false
    }

    private func loadRooms() async throws -> [PropertyRoomModel] {
        try await supabase
            .from("property_rooms")
            .select()
            .eq("property_id", value: property.id)
            .order("sort_order", ascending: true)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    private func loadRecentInspections() async throws -> [InspectionModel] {
        try await supabase
            .from("inspections")
            .select()
            .eq("property_id", value: property.id.uuidString.lowercased())
            .order("started_at", ascending: false)
            .limit(5)
            .execute()
            .value
    }

    private func loadActiveInspections() async throws -> [InspectionModel] {
        try await supabase
            .from("inspections")
            .select()
            .eq("property_id", value: property.id.uuidString.lowercased())
            .eq("status", value: "in_progress")
            .execute()
            .value
    }

    private func deleteRoom(_ room: PropertyRoomModel) async throws {
        try await supabase
            .from("property_rooms")
            .delete()
            .eq("id", value: room.id.uuidString.lowercased())
            .execute()
    }
}
