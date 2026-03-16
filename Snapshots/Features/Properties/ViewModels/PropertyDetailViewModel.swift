import SwiftUI
import Supabase

@Observable @MainActor
final class PropertyDetailViewModel {
    private struct CachedSnapshot: Codable {
        let property: PropertyModel
        let rooms: [PropertyRoomModel]
        let recentInspections: [InspectionModel]
    }

    private enum CacheConfig {
        static let keyPrefix = "property-detail"
        static let maxAge: TimeInterval = 5 * 60
    }

    enum ManageTeamDestination {
        case team
        case paywall
    }

    var property: PropertyModel
    var rooms: [PropertyRoomModel] = []
    var isLoading = false
    var hasLoadedInitialState = false
    var errorMessage: String?
    var showingAddRoom = false
    var recentInspections: [InspectionModel] = []
    private let accessManager = SnapshotsAccessManager.shared
    
    init(property: PropertyModel) {
        self.property = property
    }
    
    var isOwner: Bool {
        hasRole("owner")
    }

    var isManager: Bool {
        hasRole("manager")
    }

    var canEditRooms: Bool {
        isOwner || isManager
    }

    var canManageTeam: Bool {
        accessManager.isPro(for: property)
    }

    var manageTeamStatusText: String {
        guard canManageTeam else { return String(localized: "plan.badge.pro") }

        if isOwner {
            return String(localized: "team.role.owner")
        }

        if isManager {
            return String(localized: "team.role.manager")
        }

        return String(localized: "team.role.maintainer")
    }

    func destinationForManageTeam() -> ManageTeamDestination {
        canManageTeam ? .team : .paywall
    }
    
    func fetchRooms() async {
        isLoading = true
        errorMessage = nil
        
        do {
            rooms = try await PropertyDataService.loadRooms(propertyId: property.id)
            self.isLoading = false
        } catch is CancellationError {
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    func loadInitialData() async {
        if let cachedSnapshot = await SnapshotCache.shared.load(
            CachedSnapshot.self,
            key: Self.cacheKey(for: property.id),
            maxAge: CacheConfig.maxAge
        ) {
            property = cachedSnapshot.property
            rooms = cachedSnapshot.rooms
            recentInspections = cachedSnapshot.recentInspections
        }

        hasLoadedInitialState = true
        await fetchData(showLoadingState: rooms.isEmpty)
    }

    func fetchData(showLoadingState: Bool = true) async {
        if showLoadingState {
            isLoading = true
        }
        errorMessage = nil
        do {
            async let propertyTask = PropertyDataService.loadProperty(id: property.id)
            async let snapshotTask = PropertyDataService.loadPropertyDetailSnapshot(propertyId: property.id)
            let refreshedProperty = try await propertyTask
            let snapshot = try await snapshotTask
            property = refreshedProperty
            rooms = snapshot.rooms
            recentInspections = snapshot.recentInspections
            await persistCurrentSnapshot()
            isLoading = false
            hasLoadedInitialState = true
        } catch is CancellationError {
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            hasLoadedInitialState = true
        }
    }

    private func persistCurrentSnapshot() async {
        await SnapshotCache.shared.save(
            CachedSnapshot(
                property: property,
                rooms: rooms,
                recentInspections: recentInspections
            ),
            key: Self.cacheKey(for: property.id)
        )
    }
    
    func fetchRecentInspections() async {
        do {
            recentInspections = try await PropertyDataService.loadRecentInspections(propertyId: property.id)
        } catch {
            recentInspections = []
        }
    }
    
    /// Returns count of inspection items for the given rooms that belong to an in-progress inspection.
    func activeInspectionItemCount(at offsets: IndexSet) async throws -> Int {
        let roomIds = offsets.map { rooms[$0].id }
        return try await PropertyDataService.activeInspectionItemCount(propertyId: property.id, roomIds: roomIds)
    }
    
    func deleteRooms(at offsets: IndexSet) async -> Bool {
        let itemsToDelete = offsets.map { rooms[$0] }
        var allDeleted = true
        
        for item in itemsToDelete {
            do {
                try await PropertyDataService.deleteRoom(id: item.id)
                
                if let index = rooms.firstIndex(where: { $0.id == item.id }) {
                    rooms.remove(at: index)
                }
                await persistCurrentSnapshot()
            } catch {
                self.errorMessage = "Could not delete room. Please try again."
                allDeleted = false
            }
        }

        return allDeleted
    }

    func activeInspectionCount() async throws -> Int {
        try await PropertyDataService.activeInspectionCount(propertyId: property.id)
    }

    func deleteProperty() async -> Bool {
        do {
            try await PropertyDataService.deleteProperty(id: property.id)
            await SnapshotCache.shared.remove(key: Self.cacheKey(for: property.id))
            if let userId = try? await supabase.auth.session.user.id,
               var cachedProperties = await SnapshotCache.shared.load(
                    [PropertyModel].self,
                    key: SnapshotCacheKey.properties(for: userId)
               ) {
                cachedProperties.removeAll { $0.id == property.id }
                await SnapshotCache.shared.save(cachedProperties, key: SnapshotCacheKey.properties(for: userId))
            }
            return true
        } catch {
            errorMessage = "Could not delete property. Please try again."
            return false
        }
    }

    private func hasRole(_ role: String) -> Bool {
        property.membershipRole == role
    }

    private static func cacheKey(for propertyId: UUID) -> String {
        SnapshotCacheKey.propertyDetail(for: propertyId)
    }
}
