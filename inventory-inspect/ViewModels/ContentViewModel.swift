import SwiftUI
import Supabase

@Observable
final class ContentViewModel {
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
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    func deleteProperties(at offsets: IndexSet) {
        // Implement Supabase deletion logic here in the future
        // For now, let's just remove them from the UI
        properties.remove(atOffsets: offsets)
        // TODO: Map to actual Supabase API call
    }
}
