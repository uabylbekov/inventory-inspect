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
