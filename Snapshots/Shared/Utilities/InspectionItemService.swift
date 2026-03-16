import Foundation
import Supabase

enum InspectionItemService {
    static func saveInspectionItem(
        inspectionId: UUID,
        roomId: UUID,
        inventoryItemId: UUID,
        property: PropertyModel?,
        status: String,
        notes: String,
        existingImageURL: String?,
        imageData: Data?,
        shouldRemoveImage: Bool
    ) async throws -> String? {
        let existingFilePath = InspectionImageStorage.normalizePath(existingImageURL)
        var currentImageURL = existingImageURL
        var uploadedNewFilePath: String?
        var filePathToDeleteAfterSave: String?

        if imageData != nil {
            let accessManager = SnapshotsAccessManager.shared
            let photoCheck = await accessManager.canAttachPhoto(to: property, existingImageURL: existingImageURL)
            if case .failure(let error) = photoCheck {
                throw error
            }
        }

        do {
            if let imageData {
                let filePath = imagePath(inspectionId: inspectionId, inventoryItemId: inventoryItemId)
                _ = try await supabase.storage
                    .from(InspectionImageStorage.bucket)
                    .upload(filePath, data: imageData, options: FileOptions(contentType: "image/jpeg"))
                uploadedNewFilePath = filePath
                currentImageURL = filePath
            } else if shouldRemoveImage {
                currentImageURL = nil
                filePathToDeleteAfterSave = existingFilePath
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

            if let uploadedNewFilePath,
               let existingFilePath,
               existingFilePath != uploadedNewFilePath {
                _ = try? await supabase.storage
                    .from(InspectionImageStorage.bucket)
                    .remove(paths: [existingFilePath])
            } else if let filePathToDeleteAfterSave {
                _ = try? await supabase.storage
                    .from(InspectionImageStorage.bucket)
                    .remove(paths: [filePathToDeleteAfterSave])
            }
        } catch {
            if let uploadedNewFilePath {
                _ = try? await supabase.storage
                    .from(InspectionImageStorage.bucket)
                    .remove(paths: [uploadedNewFilePath])
            }
            throw error
        }

        await SnapshotsAccessManager.shared.refreshPhotoUsageForCurrentUser()

        return currentImageURL
    }

    private static func imagePath(inspectionId: UUID, inventoryItemId: UUID) -> String {
        let version = UUID().uuidString.lowercased()
        return "\(inspectionId.uuidString.lowercased())/\(inventoryItemId.uuidString.lowercased())-\(version).jpg"
    }
}
