import SwiftUI
import Supabase

@Observable
final class InventoryItemDetailViewModel {
    let item: RoomInventoryItemModel
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
            // Fetch past inspection records for this specific inventory item
            let records: [InspectionItemModel] = try await supabase
                .from("inspection_items")
                .select()
                .eq("inventory_item_id", value: item.id)
                .order("updated_at", ascending: false)
                .execute()
                .value
                
            self.history = records
            self.isLoading = false
        } catch is CancellationError {
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}
