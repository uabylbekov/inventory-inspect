import SwiftUI
import Supabase

@Observable @MainActor
final class PropertyViewModel {
    private enum CacheConfig {
        static let keyPrefix = "properties"
        static let maxAge: TimeInterval = 5 * 60
    }

    enum AddPropertyDestination {
        case addProperty
        case paywall
    }

    var showingAddProperty = false
    var showingPaywall = false
    var isLoading = false
    var errorMessage: String?
    var properties: [PropertyModel] = []
    var hasLoadedInitialState = false
    
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

            let fetchedProperties = try await PropertyAccessService.loadAccessibleProperties(for: userId)
            properties = fetchedProperties
            await SnapshotCache.shared.save(fetchedProperties, key: Self.cacheKey(for: userId))
            Task(priority: .utility) {
                await PrefetchService.prefetchPropertyDetails(fetchedProperties)
            }
            isLoading = false
            hasLoadedInitialState = true
        } catch is CancellationError {
            self.isLoading = false
        } catch {
            print("PropertyViewModel: Fetch Error: \(error)")
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            self.hasLoadedInitialState = true
        }
    }

    func loadInitialData() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id

            if let cachedProperties = await SnapshotCache.shared.load(
                [PropertyModel].self,
                key: Self.cacheKey(for: userId),
                maxAge: CacheConfig.maxAge
            ) {
                properties = cachedProperties
            }
        } catch {
            // Fall through to the network refresh below.
        }

        hasLoadedInitialState = true
        await fetchProperties(showLoadingState: properties.isEmpty)
    }
    
    /// Returns the number of active (in_progress) inspections for the properties at the given offsets.
    func activeInspectionCount(at offsets: IndexSet) async throws -> Int {
        let ids = offsets.map { properties[$0].id.uuidString.lowercased() }
        let existing: [InspectionModel] = try await supabase
            .from("inspections")
            .select()
            .in("property_id", values: ids)
            .eq("status", value: "in_progress")
            .execute()
            .value
        return existing.count
    }
    
    /// Returns the number of active (in_progress) inspections for a single property ID.
    func activeInspectionCount(for propertyId: UUID) async throws -> Int {
        let existing: [InspectionModel] = try await supabase
            .from("inspections")
            .select()
            .eq("property_id", value: propertyId.uuidString.lowercased())
            .eq("status", value: "in_progress")
            .execute()
            .value
        return existing.count
    }
    
    func deleteProperty(id: UUID) async -> Bool {
        do {
            try await supabase
                .from("properties")
                .delete()
                .eq("id", value: id.uuidString.lowercased())
                .execute()

            properties.removeAll { $0.id == id }

            if let userId = accessManager.profile?.id {
                await SnapshotCache.shared.save(properties, key: Self.cacheKey(for: userId))
            }

            await SnapshotCache.shared.remove(key: SnapshotCacheKey.propertyDetail(for: id))
            return true
        } catch {
            print("Failed to delete property: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func ownedPropertyCount(for userId: UUID?) -> Int {
        guard let userId else { return 0 }
        return properties.filter { $0.owner_id == userId }.count
    }

    private static func cacheKey(for userId: UUID) -> String {
        SnapshotCacheKey.properties(for: userId)
    }
}
