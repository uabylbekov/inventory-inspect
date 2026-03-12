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
            let session = try await supabase.auth.session
            properties = try await PropertyAccessService.loadAccessibleProperties(for: session.user.id)
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
    
    /// Returns true if a same-day move-in or move-out already exists for this property.
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
}
