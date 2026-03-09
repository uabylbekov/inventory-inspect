import SwiftUI
import Supabase

@Observable @MainActor
final class PropertyViewModel {
    var showingAddProperty = false
    var isLoading = false
    var errorMessage: String?
    var properties: [PropertyModel] = []

    func fetchProperties() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.session
            let ownerId = session.user.id
            
            // Fetch properties tied to the current owner via the property_members table
            let fetchedProperties: [PropertyModel] = try await supabase
                .from("properties")
                .select("*, property_members!inner(role)")
                .eq("property_members.user_id", value: ownerId)
                .order("created_at", ascending: false)
                .execute()
                .value
                
            self.properties = fetchedProperties
            self.isLoading = false
        } catch is CancellationError {
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    /// Returns the number of active (in_progress) inspections for the properties at the given offsets.
    func activeInspectionCount(at offsets: IndexSet) async -> Int {
        let ids = offsets.map { properties[$0].id.uuidString.lowercased() }
        do {
            let existing: [InspectionModel] = try await supabase
                .from("inspections")
                .select()
                .in("property_id", values: ids)
                .eq("status", value: "in_progress")
                .execute()
                .value
            return existing.count
        } catch {
            return 0
        }
    }
    
    /// Returns the number of active (in_progress) inspections for a single property ID.
    func activeInspectionCount(for propertyId: UUID) async -> Int {
        do {
            let existing: [InspectionModel] = try await supabase
                .from("inspections")
                .select()
                .eq("property_id", value: propertyId.uuidString.lowercased())
                .eq("status", value: "in_progress")
                .execute()
                .value
            return existing.count
        } catch {
            return 0
        }
    }
    
    func deleteProperties(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { properties[$0] }
        properties.remove(atOffsets: offsets)
        
        Task {
            for item in itemsToDelete {
                do {
                    try await supabase
                        .from("properties")
                        .delete()
                        .eq("id", value: item.id.uuidString.lowercased())
                        .execute()
                } catch {
                    print("Failed to delete property: \(error)")
                }
            }
        }
    }
}
