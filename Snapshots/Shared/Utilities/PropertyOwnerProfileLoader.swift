import Foundation
import Supabase

struct PropertyOwnerProfileLoader {
    private struct OwnerProfileRecord: Codable {
        let id: UUID
        let subscription_tier: String
        let full_name: String?
        let email: String?
        let company_logo_url: String?
    }

    static func enrich(_ properties: [PropertyModel]) async throws -> [PropertyModel] {
        guard !properties.isEmpty else { return properties }

        let ownerIds = Array(Set(properties.map { $0.owner_id.uuidString.lowercased() }))
        let ownerProfiles: [OwnerProfileRecord] = try await supabase
            .from("profiles")
            .select("id, subscription_tier, full_name, email, company_logo_url")
            .in("id", values: ownerIds)
            .execute()
            .value

        let ownerById = Dictionary(
            uniqueKeysWithValues: ownerProfiles.map {
                (
                    $0.id,
                    PropertyModel.OwnerProfile(
                        subscription_tier: $0.subscription_tier,
                        full_name: $0.full_name,
                        email: $0.email,
                        company_logo_url: $0.company_logo_url
                    )
                )
            }
        )

        return properties.map { property in
            PropertyModel(
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
                property_members: property.property_members,
                owner: ownerById[property.owner_id]
            )
        }
    }
}

struct PropertyAccessService {
    private struct AccessiblePropertyRow: Codable {
        let property_id: UUID
        let owner_id: UUID
        let owner_tier: String
        let owner_full_name: String?
        let owner_email: String?
        let owner_company_logo_url: String?
        let membership_role: String
    }

    static func loadAccessibleProperties(for userId: UUID) async throws -> [PropertyModel] {
        if let contractProperties = try await fetchViaAccessContract(userId: userId) {
            return contractProperties
        }

        let fetchedProperties: [PropertyModel] = try await supabase
            .from("properties")
            .select("*, property_members!inner(role)")
            .eq("property_members.user_id", value: userId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .execute()
            .value

        return try await PropertyOwnerProfileLoader.enrich(fetchedProperties)
    }

    private static func fetchViaAccessContract(userId: UUID) async throws -> [PropertyModel]? {
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
}
