import Foundation
import Supabase

@Observable @MainActor
final class StartInspectionViewModel {
    var selectedPropertyId: UUID?
    var inspectionType = "routine"
    var isSaving = false
    var errorMessage: String?
    var duplicateWarning: String?   // non-nil = show warning alert before proceeding
    var activeInspectionId: UUID?   // if found, user can join it
    var isCheckingActive = false
    
    var properties: [PropertyModel] = []
    var isLoadingProperties = true

    private struct AccessiblePropertyRow: Codable {
        let property_id: UUID
        let owner_id: UUID
        let owner_tier: String
        let owner_full_name: String?
        let owner_email: String?
        let owner_company_logo_url: String?
        let membership_role: String
    }

    init(preloadedProperties: [PropertyModel] = []) {
        self.properties = preloadedProperties
        self.isLoadingProperties = preloadedProperties.isEmpty
    }
    
    func fetchProperties(forceRefresh: Bool = false) async {
        if !forceRefresh && !properties.isEmpty {
            isLoadingProperties = false
            return
        }

        isLoadingProperties = true
        errorMessage = nil
        do {
            properties = try await loadProperties()
            isLoadingProperties = false
        } catch is CancellationError {
            self.isLoadingProperties = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoadingProperties = false
        }
    }
    
    func checkActiveInspection() async {
        guard let propertyId = selectedPropertyId else { return }
        isCheckingActive = true
        activeInspectionId = nil
        defer { isCheckingActive = false }

        do {
            activeInspectionId = try await fetchActiveInspectionID(for: propertyId)
        } catch {
            activeInspectionId = nil
        }
    }
    
    /// Returns true if a same-day check-in or check-out already exists for this property.
    /// Routine inspections are never checked.
    func checkForDuplicate() async -> Bool {
        guard let propertyId = selectedPropertyId,
              inspectionType != "routine" else { return false }

        do {
            let existing: [InspectionModel] = try await supabase
                .from("inspections")
                .select()
                .eq("property_id", value: propertyId.uuidString.lowercased())
                .eq("inspection_type", value: inspectionType)
                .gte("started_at", value: startOfTodayString())
                .execute()
                .value
            return !existing.isEmpty
        } catch {
            return false
        }
    }
    
    func startInspection() async -> UUID? {
        guard let propertyId = selectedPropertyId else {
            self.errorMessage = "Please select a property."
            return nil
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            let inspectionID = try await createInspection(for: propertyId)
            isSaving = false
            return inspectionID
        } catch is CancellationError {
            self.isSaving = false
            return nil
        } catch {
            self.errorMessage = errorMessage(for: error)
            self.isSaving = false
            return nil
        }
    }

    private func loadProperties() async throws -> [PropertyModel] {
        let session = try await supabase.auth.session
        let userId = session.user.id

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

    private func fetchActiveInspectionID(for propertyId: UUID) async throws -> UUID? {
        let existing: [InspectionModel] = try await supabase
            .from("inspections")
            .select()
            .eq("property_id", value: propertyId.uuidString.lowercased())
            .eq("status", value: "in_progress")
            .execute()
            .value

        return existing.first?.id
    }

    private func createInspection(for propertyId: UUID) async throws -> UUID? {
        let session = try await supabase.auth.session
        let newInspection = InspectionInsert(
            property_id: propertyId,
            inspector_id: session.user.id,
            inspection_type: inspectionType
        )

        let created: [InspectionModel] = try await supabase
            .from("inspections")
            .insert(newInspection)
            .select()
            .execute()
            .value

        return created.first?.id
    }

    private func startOfTodayString() -> String {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: todayStart)
    }

    private func errorMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.contains("unq_active_inspection_per_property") || message.contains("duplicate key value") {
            return "An inspection is already in progress for this property. Please wait for it to be completed or cancelled."
        }
        return message
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
}
