import SwiftUI
import Supabase

@Observable @MainActor
final class PropertyViewModel {
    enum AddPropertyDestination {
        case addProperty
        case paywall
    }

    var showingAddProperty = false
    var showingPaywall = false
    var isLoading = false
    var errorMessage: String?
    var properties: [PropertyModel] = []
    
    private let accessManager = SnapshotsAccessManager.shared

    var isResolvingAddPropertyAccess: Bool {
        accessManager.isCheckingAccess
    }

    func canAddProperty() -> Bool {
        let ownedCount = ownedPropertyCount(for: accessManager.profile?.id)
        return accessManager.canAddProperty(ownedCount: ownedCount)
    }

    func destinationForAddProperty() -> AddPropertyDestination? {
        guard !isResolvingAddPropertyAccess else { return nil }
        return canAddProperty() ? .addProperty : .paywall
    }

    func fetchProperties(showLoadingState: Bool = true) async {
        if showLoadingState {
            isLoading = true
        }
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id

            properties = try await PropertyAccessService.loadAccessibleProperties(for: userId)
            isLoading = false
        } catch is CancellationError {
            self.isLoading = false
        } catch {
            print("PropertyViewModel: Fetch Error: \(error)")
            self.errorMessage = error.localizedDescription
            self.isLoading = false
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

    private func ownedPropertyCount(for userId: UUID?) -> Int {
        guard let userId else { return 0 }
        return properties.filter { $0.owner_id == userId }.count
    }
}
