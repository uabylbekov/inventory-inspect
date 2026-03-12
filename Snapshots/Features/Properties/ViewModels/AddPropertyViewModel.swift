import Foundation

import Supabase

@Observable @MainActor
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

    // MARK: - Country List
    static let allCountries: [(name: String, code: String)] = {
        let locale = Locale.autoupdatingCurrent
        return Locale.Region.isoRegions
            .compactMap { region -> (name: String, code: String)? in
                guard let name = locale.localizedString(forRegionCode: region.identifier) else { return nil }
                return (name: name, code: region.identifier)
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }()

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
        nameError != nil || isSaving
    }

    // MARK: - Save
    func saveToSupabase() async -> Bool {
        isSaving = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.session
            let ownerId = session.user.id

            let canCreate = try await remoteCanCreateProperty(userId: ownerId)
            if !canCreate {
                self.errorMessage = "Property limit reached for your current plan."
                self.isSaving = false
                return false
            }

            let newProperty = PropertyInsert(
                owner_id: ownerId,
                name: name.trimmingCharacters(in: .whitespaces),
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

            try await supabase.from("properties")
                .insert(newProperty)
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

    private func remoteCanCreateProperty(userId: UUID) async throws -> Bool {
        let params: [String: AnyJSON] = ["p_user_id": .string(userId.uuidString.lowercased())]
        do {
            let allowed: Bool = try await supabase
                .rpc("can_user_create_property", params: params)
                .execute()
                .value
            return allowed
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("could not find the function")
                || message.contains("function public.can_user_create_property")
                || message.contains("schema cache") {
                throw NSError(
                    domain: "AddPropertyViewModel",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "Property billing rules are unavailable in this environment. Apply the latest database migrations before creating properties."]
                )
            }
            throw error
        }
    }
}
