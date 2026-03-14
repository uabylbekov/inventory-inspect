import Foundation
import Supabase

@Observable @MainActor
final class InspectionHubViewModel {
    private struct CachedSnapshot: Codable {
        let property: PropertyModel?
        let rooms: [PropertyRoomModel]
        let inventoryItems: [RoomInventoryItemModel]
        let inspectionItems: [InspectionItemModel]
    }

    private enum CacheConfig {
        static let keyPrefix = "inspection-hub"
        static let maxAge: TimeInterval = 5 * 60
    }

    let inspection: InspectionModel
    
    var rooms: [PropertyRoomModel] = []
    var property: PropertyModel? = nil
    var allInventoryItems: [RoomInventoryItemModel] = []
    var inspectionItems: [InspectionItemModel] = []
    
    var roomProgressList: [RoomProgress] = []
    
    var isLoading = false
    var hasLoadedInitialState = false
    var isCompleting = false
    var errorMessage: String?
    
    private var channel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var fallbackPollingTask: Task<Void, Never>?
    
    init(inspection: InspectionModel) {
        self.inspection = inspection
    }
    
    func unsubscribe() {
        let ch = channel
        realtimeTask?.cancel()
        realtimeTask = nil
        fallbackPollingTask?.cancel()
        fallbackPollingTask = nil
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

    func loadInitialData() async {
        if let cachedSnapshot = await SnapshotCache.shared.load(
            CachedSnapshot.self,
            key: Self.cacheKey(for: inspection.id),
            maxAge: CacheConfig.maxAge
        ) {
            apply(snapshot: cachedSnapshot)
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
            let snapshot = try await InspectionDataService.loadInspectionHubSnapshot(for: inspection)
            let cachedSnapshot = CachedSnapshot(
                property: snapshot.property,
                rooms: snapshot.rooms,
                inventoryItems: snapshot.inventoryItems,
                inspectionItems: snapshot.inspectionItems
            )
            apply(snapshot: cachedSnapshot)
            await SnapshotCache.shared.save(cachedSnapshot, key: Self.cacheKey(for: inspection.id))
            isLoading = false
            hasLoadedInitialState = true
        } catch {
            if error is CancellationError {
                isLoading = false
            } else {
                errorMessage = error.localizedDescription
                isLoading = false
                hasLoadedInitialState = true
            }
        }
    }
    
    func setupRealtime() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        let channel = supabase.channel("inspection_updates")

        do {
            let observation = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "inspection_items",
                filter: .eq("inspection_id", value: inspection.id.uuidString.lowercased())
            )

            try await channel.subscribeWithError()
            fallbackPollingTask?.cancel()
            fallbackPollingTask = nil
            if errorMessage == "Live updates unavailable. Refreshing periodically." {
                errorMessage = nil
            }

            realtimeTask = Task { [weak self] in
                guard let self else { return }
                for await change in observation {
                    switch change {
                    case .insert(let action):
                        if let updatedRecord = try? action.decodeRecord(as: InspectionItemModel.self, decoder: JSONDecoder()) {
                            applyRealtimeChange(updatedRecord)
                        } else {
                            await fetchData(showLoadingState: false)
                        }
                    case .update(let action):
                        if let updatedRecord = try? action.decodeRecord(as: InspectionItemModel.self, decoder: JSONDecoder()) {
                            applyRealtimeChange(updatedRecord)
                        } else {
                            await fetchData(showLoadingState: false)
                        }
                    default:
                        await fetchData(showLoadingState: false)
                    }
                }
            }
            self.channel = channel
        } catch {
            print("Inspection realtime unavailable, falling back to polling: \(error)")
            await channel.unsubscribe()
            self.channel = nil
            errorMessage = "Live updates unavailable. Refreshing periodically."
            fallbackPollingTask?.cancel()
            fallbackPollingTask = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    await fetchData(showLoadingState: false)
                    try? await Task.sleep(for: .seconds(20))
                }
            }
        }
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

    private func apply(snapshot: CachedSnapshot) {
        rooms = snapshot.rooms
        property = snapshot.property
        allInventoryItems = snapshot.inventoryItems
        inspectionItems = snapshot.inspectionItems
        calculateProgress()
    }

    private func applyRealtimeChange(_ record: InspectionItemModel) {
        if let existingIndex = inspectionItems.firstIndex(where: { $0.id == record.id }) {
            inspectionItems[existingIndex] = record
        } else {
            inspectionItems.append(record)
        }

        calculateProgress()
        persistCurrentSnapshot()
    }

    private func persistCurrentSnapshot() {
        Task(priority: .utility) {
            await SnapshotCache.shared.save(
            CachedSnapshot(
                property: property,
                rooms: rooms,
                inventoryItems: allInventoryItems,
                inspectionItems: inspectionItems
            ),
            key: Self.cacheKey(for: inspection.id)
            )
        }
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
            await InspectionBadgeStore.shared.refresh()
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
            await InspectionBadgeStore.shared.refresh()
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
            await SnapshotCache.shared.remove(key: SnapshotCacheKey.inspectionHub(for: inspection.id))
            await SnapshotCache.shared.remove(key: SnapshotCacheKey.inspectionReport(for: inspection.id))
            if let userId = try? await supabase.auth.session.user.id,
               var cachedInspections = await SnapshotCache.shared.load(
                    [InspectionModel].self,
                    key: SnapshotCacheKey.inspections(for: userId)
               ) {
                cachedInspections.removeAll { $0.id == inspection.id }
                await SnapshotCache.shared.save(cachedInspections, key: SnapshotCacheKey.inspections(for: userId))
            }
            await InspectionBadgeStore.shared.refresh()
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func cacheKey(for inspectionId: UUID) -> String {
        SnapshotCacheKey.inspectionHub(for: inspectionId)
    }
}
