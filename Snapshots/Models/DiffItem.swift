import Foundation
import Supabase

struct DiffItem: Identifiable {
    let id = UUID()
    let inventoryItemId: UUID
    let itemName: String
    let roomName: String
    
    let oldStatus: String
    let oldNotes: String?
    let oldImage: String?
    
    let newStatus: String
    let newNotes: String?
    let newImage: String?
}
