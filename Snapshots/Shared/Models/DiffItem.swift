import Foundation
import Supabase

struct DiffItem: Codable, Hashable, Identifiable {
    let inventoryItemId: UUID
    let itemName: String
    let roomName: String
    
    let oldStatus: String
    let oldNotes: String?
    let oldImage: String?
    
    let newStatus: String
    let newPreviousStatus: String?
    let newNotes: String?
    let newImage: String?

    var id: String {
        [
            inventoryItemId.uuidString.lowercased(),
            oldStatus,
            newStatus,
            newPreviousStatus ?? "",
            newNotes ?? "",
            oldImage ?? "",
            newImage ?? ""
        ].joined(separator: "|")
    }
}
