import Foundation
import Supabase

@Observable
final class EditPropertyViewModel {
    let propertyId: UUID
    
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
    
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    
    // MARK: - Validation

    var nameError: String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Property name is required." }
        if trimmed.count > 100 { return "Name must be 100 characters or fewer." }
        return nil
    }

    var maxGuestsError: String? {
        guard !maxGuests.isEmpty else { return nil }
        guard let value = Int(maxGuests), value > 0 else {
            return "Max guests must be a positive whole number."
        }
        return nil
    }

    var postalCodeError: String? {
        let trimmed = postalCode.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count > 20 { return "Postal code is too long." }
        return nil
    }

    var isFormValid: Bool {
        nameError == nil && maxGuestsError == nil && postalCodeError == nil
    }

    var isSaveDisabled: Bool {
        nameError != nil || isSaving || isLoading
    }
    
    init(propertyId: UUID) {
        self.propertyId = propertyId
    }
    
    func fetchProperty() async {
        isLoading = true
        errorMessage = nil
        do {
            let data: AnyJSON = try await supabase
                .from("properties")
                .select()
                .eq("id", value: propertyId.uuidString.lowercased())
                .single()
                .execute()
                .value
                
            if case .object(let dict) = data {
                name = dict["name"]?.stringValue ?? ""
                description = dict["description"]?.stringValue ?? ""
                type = dict["property_type"]?.stringValue ?? "Apartment"
                status = dict["status"]?.stringValue ?? "active"
                country = dict["country"]?.stringValue ?? "United States"
                stateRegion = dict["state_region"]?.stringValue ?? ""
                city = dict["city"]?.stringValue ?? ""
                addressLine1 = dict["address_line1"]?.stringValue ?? ""
                addressLine2 = dict["address_line2"]?.stringValue ?? ""
                postalCode = dict["postal_code"]?.stringValue ?? ""
                if let beds = dict["bedrooms_count"]?.intValue { bedroomsCount = beds }
                if let baths = dict["bathrooms_count"]?.doubleValue { bathroomsCount = baths }
                if let guests = dict["max_guests"]?.intValue { maxGuests = "\(guests)" }
                airbnbListingId = dict["airbnb_listing_id"]?.stringValue ?? ""
                vrboListingId = dict["vrbo_listing_id"]?.stringValue ?? ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func saveToSupabase() async -> Bool {
        isSaving = true
        errorMessage = nil
        
        do {
            var params: [String: AnyJSON] = [
                "name": .string(name),
                "property_type": .string(type),
                "status": .string(status),
                "country": .string(country),
                "bedrooms_count": .integer(bedroomsCount),
                "bathrooms_count": .double(bathroomsCount)
            ]
            
            params["description"] = description.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(description)
            params["state_region"] = stateRegion.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(stateRegion)
            params["city"] = city.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(city)
            params["address_line1"] = addressLine1.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(addressLine1)
            params["address_line2"] = addressLine2.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(addressLine2)
            params["postal_code"] = postalCode.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(postalCode)
            if let guests = Int(maxGuests) {
                params["max_guests"] = .integer(guests)
            } else {
                params["max_guests"] = .null
            }
            params["airbnb_listing_id"] = airbnbListingId.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(airbnbListingId)
            params["vrbo_listing_id"] = vrboListingId.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(vrboListingId)
            
            try await supabase
                .from("properties")
                .update(params)
                .eq("id", value: propertyId.uuidString.lowercased())
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
