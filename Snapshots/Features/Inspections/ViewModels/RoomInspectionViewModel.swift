import Foundation
import Supabase

@Observable @MainActor
final class RoomInspectionViewModel {
    let inspection: InspectionModel
    let room: PropertyRoomModel
    
    var items: [RoomInventoryItemModel] = []
    var existingRecords: [UUID: InspectionItemModel] = [:]
    
    var isLoading = false
    var errorMessage: String?
    
    init(inspection: InspectionModel, room: PropertyRoomModel) {
        self.inspection = inspection
        self.room = room
    }
    
    func fetchData() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await InspectionDataService.loadRoomInspectionSnapshot(
                inspectionId: inspection.id,
                roomId: room.id
            )
            self.items = snapshot.items
            self.existingRecords = snapshot.existingRecords
            
            isLoading = false
        } catch is CancellationError {
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
