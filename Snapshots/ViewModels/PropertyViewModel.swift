import SwiftUI
import Supabase

@Observable @MainActor
final class PropertyViewModel {
    var showingAddProperty = false
    var showingPaywall = false
    var isLoading = false
    var errorMessage: String?
    var properties: [PropertyModel] = []
    
    private let accessManager = SnapshotsAccessManager.shared
    
    private struct AccessiblePropertyRow: Codable {
        let property_id: UUID
        let owner_id: UUID
        let owner_tier: String
        let owner_full_name: String?
        let owner_email: String?
        let owner_company_logo_url: String?
        let membership_role: String
    }

    func canAddProperty() -> Bool {
        guard let userId = accessManager.profile?.id else { return false }
        let ownedCount = properties.filter { $0.owner_id == userId }.count
        return accessManager.canAddProperty(ownedCount: ownedCount)
    }

    func fetchProperties() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id

            if let contractProperties = try await fetchViaAccessContract(userId: userId) {
                self.properties = contractProperties
                self.isLoading = false
                return
            }
            
            let fetchedProperties: [PropertyModel] = try await supabase
                .from("properties")
                .select("*, property_members!inner(role)")
                .eq("property_members.user_id", value: userId.uuidString.lowercased())
                .order("created_at", ascending: false)
                .execute()
                .value

            self.properties = try await PropertyOwnerProfileLoader.enrich(fetchedProperties)
            self.isLoading = false
        } catch is CancellationError {
            self.isLoading = false
        } catch {
            print("PropertyViewModel: Fetch Error: \(error)")
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    private func fetchViaAccessContract(userId: UUID) async throws -> [PropertyModel]? {
        let params: [String: AnyJSON] = ["p_user_id": .string(userId.uuidString.lowercased())]

        let accessRows: [AccessiblePropertyRow]
        do {
            accessRows = try await supabase
                .rpc("get_accessible_properties_with_owner_tier", params: params)
                .execute()
                .value
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("could not find the function")
                || message.contains("function public.get_accessible_properties_with_owner_tier")
                || message.contains("schema cache") {
                return nil
            }
            throw error
        }

        if accessRows.isEmpty {
            return []
        }

        let propertyIds = accessRows.map { $0.property_id.uuidString.lowercased() }
        let fetchedProperties: [PropertyModel] = try await supabase
            .from("properties")
            .select()
            .in("id", values: propertyIds)
            .order("created_at", ascending: false)
            .execute()
            .value

        let accessByPropertyId = Dictionary(uniqueKeysWithValues: accessRows.map { ($0.property_id, $0) })

        return fetchedProperties.compactMap { property in
            guard let access = accessByPropertyId[property.id] else { return nil }
            return PropertyModel(
                id: property.id,
                owner_id: property.owner_id,
                name: property.name,
                description: property.description,
                property_type: property.property_type,
                country: property.country,
                address_line1: property.address_line1,
                bedrooms_count: property.bedrooms_count,
                bathrooms_count: property.bathrooms_count,
                created_at: property.created_at,
                property_members: [PropertyMemberModel(role: access.membership_role)],
                owner: PropertyModel.OwnerProfile(
                    subscription_tier: access.owner_tier,
                    full_name: access.owner_full_name,
                    email: access.owner_email,
                    company_logo_url: access.owner_company_logo_url
                )
            )
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
