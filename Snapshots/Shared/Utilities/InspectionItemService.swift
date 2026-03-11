import Foundation
import Supabase

enum InspectionItemService {
    static func saveInspectionItem(
        inspectionId: UUID,
        roomId: UUID,
        inventoryItemId: UUID,
        status: String,
        notes: String,
        existingImageURL: String?,
        imageData: Data?,
        shouldRemoveImage: Bool
    ) async throws -> String? {
        let filePath = imagePath(inspectionId: inspectionId, inventoryItemId: inventoryItemId)
        var currentImageURL = existingImageURL

        if let imageData {
            _ = try await supabase.storage
                .from("inspection-images")
                .upload(filePath, data: imageData, options: FileOptions(contentType: "image/jpeg", upsert: true))

            let publicURL = try supabase.storage
                .from("inspection-images")
                .getPublicURL(path: filePath)
            currentImageURL = publicURL.absoluteString
        } else if shouldRemoveImage {
            _ = try? await supabase.storage
                .from("inspection-images")
                .remove(paths: [filePath])
            currentImageURL = nil
        }

        let params: [String: AnyJSON] = [
            "inspection_id": .string(inspectionId.uuidString.lowercased()),
            "room_id": .string(roomId.uuidString.lowercased()),
            "inventory_item_id": .string(inventoryItemId.uuidString.lowercased()),
            "status": .string(status),
            "notes": .string(notes),
            "image_url": currentImageURL.map(AnyJSON.string) ?? .null
        ]

        try await supabase
            .from("inspection_items")
            .upsert(params, onConflict: "inspection_id,inventory_item_id")
            .execute()

        return currentImageURL
    }

    private static func imagePath(inspectionId: UUID, inventoryItemId: UUID) -> String {
        "\(inspectionId.uuidString.lowercased())/\(inventoryItemId.uuidString.lowercased()).jpg"
    }
}
