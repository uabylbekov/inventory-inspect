import SwiftUI
import Supabase

@Observable
final class InventoryItemDetailViewModel {
    var item: RoomInventoryItemModel
    var history: [InspectionItemModel] = []
    var isLoading = false
    var errorMessage: String?
    
    init(item: RoomInventoryItemModel) {
        self.item = item
    }
    
    func fetchHistory() async {
        isLoading = true
        errorMessage = nil
        
        do {
            self.history = try await InspectionDataService.loadInventoryHistory(for: item.id)
            self.isLoading = false
        } catch is CancellationError {
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    func refreshItem() async {
        do {
            item = try await PropertyDataService.loadInventoryItem(id: item.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem() async -> Bool {
        do {
            try await PropertyDataService.deleteInventoryItem(id: item.id)
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = "Could not delete item. Please try again."
            return false
        }
    }
}
