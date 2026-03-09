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
    
    func fetchProperties() async {
        isLoadingProperties = true
        errorMessage = nil
        do {
            let fetched: [PropertyModel] = try await supabase
                .from("properties")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            self.properties = fetched
            self.isLoadingProperties = false
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
        do {
            let existing: [InspectionModel] = try await supabase
                .from("inspections")
                .select()
                .eq("property_id", value: propertyId.uuidString.lowercased())
                .eq("status", value: "in_progress")
                .execute()
                .value
            
            self.activeInspectionId = existing.first?.id
        } catch {
            print("Error checking active inspection: \(error)")
        }
        isCheckingActive = false
    }
    
    /// Returns true if a same-day check-in or check-out already exists for this property.
    /// Routine inspections are never checked.
    func checkForDuplicate() async -> Bool {
        guard let propertyId = selectedPropertyId,
              inspectionType != "routine" else { return false }
        
        let todayStart = Calendar.current.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let todayStr = formatter.string(from: todayStart)
        
        do {
            let existing: [InspectionModel] = try await supabase
                .from("inspections")
                .select()
                .eq("property_id", value: propertyId.uuidString.lowercased())
                .eq("inspection_type", value: inspectionType)
                .gte("started_at", value: todayStr)
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
            let session = try await supabase.auth.session
            let newInspection = InspectionInsert(
                property_id: propertyId,
                inspector_id: session.user.id,
                inspection_type: inspectionType
            )
            
            // Insert and return the created inspection
            let created: [InspectionModel] = try await supabase.from("inspections")
                .insert(newInspection)
                .select()
                .execute()
                .value
            
            isSaving = false
            return created.first?.id
        } catch is CancellationError {
            self.isSaving = false
            return nil
        } catch {
            if error.localizedDescription.contains("unq_active_inspection_per_property") || error.localizedDescription.contains("duplicate key value") {
                self.errorMessage = "An inspection is already in progress for this property. Please wait for it to be completed or cancelled."
            } else {
                self.errorMessage = error.localizedDescription
            }
            self.isSaving = false
            return nil
        }
    }
}
