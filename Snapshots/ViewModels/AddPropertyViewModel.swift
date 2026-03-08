import Foundation
import SwiftData
import Supabase

@Observable
final class AddPropertyViewModel {
    var name = ""
    var description = ""
    var type = "Apartment"
    var status = "active"
    var country = "United States"
    var stateRegion = ""
    var city = ""
    var addressLine1 = ""
    var addressLine2 = ""
    var postalCode = ""
    var bedroomsCount = 1
    var bathroomsCount = 1.0
    var maxGuests = ""
    var airbnbListingId = ""
    var vrboListingId = ""
    var isSaving = false
    var errorMessage: String?
    
    var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving
    }
    
    func saveToSupabase() async -> Bool {
        isSaving = true
        errorMessage = nil
        
        do {
            // Get the current user to satisfy the owner_id constraint
            let session = try await supabase.auth.session
            let ownerId = session.user.id
            
            // Map our UI state to the required Supabase schema
            let newProperty = PropertyInsert(
                owner_id: ownerId,
                name: name,
                description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description,
                property_type: type,
                status: status,
                country: country,
                state_region: stateRegion.trimmingCharacters(in: .whitespaces).isEmpty ? nil : stateRegion,
                city: city.trimmingCharacters(in: .whitespaces).isEmpty ? nil : city,
                address_line1: addressLine1.trimmingCharacters(in: .whitespaces).isEmpty ? nil : addressLine1,
                address_line2: addressLine2.trimmingCharacters(in: .whitespaces).isEmpty ? nil : addressLine2,
                postal_code: postalCode.trimmingCharacters(in: .whitespaces).isEmpty ? nil : postalCode,
                latitude: nil,
                longitude: nil,
                bedrooms_count: bedroomsCount,
                bathrooms_count: bathroomsCount,
                max_guests: Int(maxGuests),
                airbnb_listing_id: airbnbListingId.trimmingCharacters(in: .whitespaces).isEmpty ? nil : airbnbListingId,
                vrbo_listing_id: vrboListingId.trimmingCharacters(in: .whitespaces).isEmpty ? nil : vrboListingId
            )
            
            // Insert into the public.properties table
            try await supabase.from("properties")
                .insert(newProperty)
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
