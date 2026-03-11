import Foundation
import Supabase

struct PropertyOwnerProfileLoader {
    private struct OwnerProfileRecord: Codable {
        let id: UUID
        let subscription_tier: String
        let full_name: String?
        let email: String?
        let company_logo_url: String?
        let property_limit_override: Int?
        let team_limit_override: Int?
        let photo_limit_override: Int?
    }

    static func enrich(_ properties: [PropertyModel]) async throws -> [PropertyModel] {
        guard !properties.isEmpty else { return properties }

        let ownerIds = Array(Set(properties.map { $0.owner_id.uuidString.lowercased() }))
        let ownerProfiles = try await loadOwnerProfiles(ownerIds: ownerIds)

        let ownerById = Dictionary(
            uniqueKeysWithValues: ownerProfiles.map {
                (
                    $0.id,
                    PropertyModel.OwnerProfile(
                        subscription_tier: $0.subscription_tier,
                        full_name: $0.full_name,
                        email: $0.email,
                        company_logo_url: $0.company_logo_url,
                        property_limit_override: $0.property_limit_override,
                        team_limit_override: $0.team_limit_override,
                        photo_limit_override: $0.photo_limit_override
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

    private static func loadOwnerProfiles(ownerIds: [String]) async throws -> [OwnerProfileRecord] {
        do {
            return try await supabase
                .from("profiles")
                .select("id, subscription_tier, full_name, email, company_logo_url, property_limit_override, team_limit_override, photo_limit_override")
                .in("id", values: ownerIds)
                .execute()
                .value
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("property_limit_override")
                || message.contains("team_limit_override")
                || message.contains("photo_limit_override") {
                return try await loadOwnerProfilesWithoutOverrides(ownerIds: ownerIds)
            }
            throw error
        }
    }

    private static func loadOwnerProfilesWithoutOverrides(ownerIds: [String]) async throws -> [OwnerProfileRecord] {
        struct LegacyOwnerProfileRecord: Codable {
            let id: UUID
            let subscription_tier: String
            let full_name: String?
            let email: String?
            let company_logo_url: String?
        }

        let legacyProfiles: [LegacyOwnerProfileRecord] = try await supabase
            .from("profiles")
            .select("id, subscription_tier, full_name, email, company_logo_url")
            .in("id", values: ownerIds)
            .execute()
            .value

        return legacyProfiles.map {
            OwnerProfileRecord(
                id: $0.id,
                subscription_tier: $0.subscription_tier,
                full_name: $0.full_name,
                email: $0.email,
                company_logo_url: $0.company_logo_url,
                property_limit_override: nil,
                team_limit_override: nil,
                photo_limit_override: nil
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
        let owner_property_limit_override: Int?
        let owner_team_limit_override: Int?
        let owner_photo_limit_override: Int?
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
                    company_logo_url: access.owner_company_logo_url,
                    property_limit_override: access.owner_property_limit_override,
                    team_limit_override: access.owner_team_limit_override,
                    photo_limit_override: access.owner_photo_limit_override
                )
            )
        }
    }
}
