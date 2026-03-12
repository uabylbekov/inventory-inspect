import SwiftUI
import Supabase

@Observable @MainActor
final class PropertyDetailViewModel {
    enum ManageTeamDestination {
        case team
        case paywall
    }

    var property: PropertyModel
    var rooms: [PropertyRoomModel] = []
    var isLoading = false
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
            return "Owner"
        }

        if isManager {
            return "Manager"
        }

        return "Maintainer"
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

    func fetchData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let propertyTask = PropertyDataService.loadProperty(id: property.id)
            async let snapshotTask = PropertyDataService.loadPropertyDetailSnapshot(propertyId: property.id)
            let refreshedProperty = try await propertyTask
            let snapshot = try await snapshotTask
            property = refreshedProperty
            rooms = snapshot.rooms
            recentInspections = snapshot.recentInspections
            isLoading = false
        } catch is CancellationError {
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func fetchRecentInspections() async {
        do {
            recentInspections = try await PropertyDataService.loadRecentInspections(propertyId: property.id)
        } catch {
            recentInspections = []
        }
    }
    
    /// Returns count of inspection items for the given rooms that belong to an in-progress inspection.
    func activeInspectionItemCount(at offsets: IndexSet) async -> Int {
        let roomIds = offsets.map { rooms[$0].id }
        do {
            return try await PropertyDataService.activeInspectionItemCount(propertyId: property.id, roomIds: roomIds)
        } catch {
            return 0
        }
    }
    
    func deleteRooms(at offsets: IndexSet) async {
        let itemsToDelete = offsets.map { rooms[$0] }
        
        for item in itemsToDelete {
            do {
                try await PropertyDataService.deleteRoom(id: item.id)
                
                if let index = rooms.firstIndex(where: { $0.id == item.id }) {
                    rooms.remove(at: index)
                }
            } catch {
                self.errorMessage = "Could not delete room. Please try again."
            }
        }
    }

    func activeInspectionCount() async -> Int {
        do {
            return try await PropertyDataService.activeInspectionCount(propertyId: property.id)
        } catch {
            return 0
        }
    }

    func deleteProperty() async -> Bool {
        do {
            try await PropertyDataService.deleteProperty(id: property.id)
            return true
        } catch {
            errorMessage = "Could not delete property. Please try again."
            return false
        }
    }

    private func hasRole(_ role: String) -> Bool {
        property.property_members?.contains(where: { $0.role == role }) ?? false
    }
}
