import Foundation
import Supabase

@Observable @MainActor
final class InspectionHubViewModel {
    let inspection: InspectionModel
    
    var rooms: [PropertyRoomModel] = []
    var property: PropertyModel? = nil
    var allInventoryItems: [RoomInventoryItemModel] = []
    var inspectionItems: [InspectionItemModel] = []
    
    var roomProgressList: [RoomProgress] = []
    
    var isLoading = false
    var isCompleting = false
    var errorMessage: String?
    
    private var channel: RealtimeChannelV2?
    
    init(inspection: InspectionModel) {
        self.inspection = inspection
    }
    
    func unsubscribe() {
        let ch = channel
        self.channel = nil
        if let ch {
            Task {
                await ch.unsubscribe()
            }
        }
    }
    
    struct RoomProgress: Identifiable {
        let room: PropertyRoomModel
        let totalItems: Int
        let inspectedItems: Int
        var id: UUID { room.id }
        
        var isComplete: Bool {
            totalItems > 0 && totalItems == inspectedItems
        }
        
        var progressString: String {
            if totalItems == 0 { return "Empty" }
            return "\(inspectedItems)/\(totalItems)"
        }
        
        var progressFraction: Double {
            if totalItems == 0 { return 1.0 }
            return Double(inspectedItems) / Double(totalItems)
        }
    }
    
    var allRoomsComplete: Bool {
        let totalItems = roomProgressList.reduce(0) { $0 + $1.totalItems }
        guard totalItems > 0 else { return false }  // Empty property can't be completed
        return roomProgressList.allSatisfy { $0.totalItems == 0 || $0.isComplete }
    }
    
    func fetchData() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await InspectionDataService.loadInspectionHubSnapshot(for: inspection)
            self.rooms = snapshot.rooms
            self.property = snapshot.property
            self.allInventoryItems = snapshot.inventoryItems
            self.inspectionItems = snapshot.inspectionItems
            
            calculateProgress()
            isLoading = false
        } catch {
            if error is CancellationError {
                isLoading = false
            } else {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func setupRealtime() async {
        let channel = supabase.channel("inspection_updates")
        
        let observation = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "inspection_items",
            filter: .eq("inspection_id", value: inspection.id.uuidString.lowercased())
        )
        
        Task {
            for await _ in observation {
                await fetchData()
            }
        }
        
        try? await channel.subscribeWithError()
        self.channel = channel
    }
    
    func calculateProgress() {
        var progressList: [RoomProgress] = []
        let inspectionItemIds = Set(inspectionItems.map { $0.inventory_item_id })
        
        for room in rooms {
            let itemsInRoom = allInventoryItems.filter { $0.room_id == room.id }
            let total = itemsInRoom.count
            let checkedCount = itemsInRoom.filter { inspectionItemIds.contains($0.id) }.count
            progressList.append(RoomProgress(room: room, totalItems: total, inspectedItems: checkedCount))
        }
        
        self.roomProgressList = progressList
    }
    
    func roomProgress(for roomId: UUID) -> RoomProgress? {
        roomProgressList.first(where: { $0.id == roomId })
    }
    
    func inspectionRecord(for itemId: UUID) -> InspectionItemModel? {
        inspectionItems.first(where: { $0.inventory_item_id == itemId })
    }
    
    func completeInspection() async -> Bool {
        isCompleting = true
        errorMessage = nil
        do {
            try await InspectionWorkflowService.completeInspection(id: inspection.id)
                
            isCompleting = false
            return true
        } catch is CancellationError {
            isCompleting = false
            return false
        } catch {
            errorMessage = error.localizedDescription
            isCompleting = false
            return false
        }
    }
    
    func cancelInspection(reason: String) async -> Bool {
        errorMessage = nil
        do {
            try await InspectionWorkflowService.cancelInspection(
                id: inspection.id,
                reason: reason.isEmpty ? "Cancelled" : reason
            )
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteInspection() async -> Bool {
        errorMessage = nil
        do {
            try await InspectionWorkflowService.deleteInspection(id: inspection.id)
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
