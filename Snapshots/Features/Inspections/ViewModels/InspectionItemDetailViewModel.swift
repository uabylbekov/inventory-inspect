import Foundation
import SwiftUI

@Observable @MainActor
final class InspectionItemDetailViewModel {
    let item: RoomInventoryItemModel
    let inspection: InspectionModel
    let room: PropertyRoomModel

    var status: String
    var notes: String
    var imageURL: String?
    var pendingImageData: Data?

    var isSaving = false
    var isUploading = false
    var isProcessingImage = false
    var saveError: String?
    var annotatingImage: UIImage?

    private let originalImageURL: String?
    private var shouldRemoveExistingImage = false

    init(item: RoomInventoryItemModel, inspection: InspectionModel, room: PropertyRoomModel, initialRecord: InspectionItemModel?) {
        self.item = item
        self.inspection = inspection
        self.room = room
        self.status = initialRecord?.status ?? "present"
        self.notes = initialRecord?.notes ?? ""
        self.imageURL = initialRecord?.image_url
        self.originalImageURL = initialRecord?.image_url
    }

    func updateStatus(_ newStatus: String) {
        status = newStatus
    }

    func removePhoto() {
        imageURL = nil
        pendingImageData = nil
        shouldRemoveExistingImage = originalImageURL != nil
    }

    func setAnnotatedImageData(_ data: Data) {
        pendingImageData = data
        shouldRemoveExistingImage = false
    }

    func prepareAnnotation(_ image: UIImage) {
        isProcessingImage = true
        Task.detached(priority: .userInitiated) {
            let maxDimension: CGFloat = 2048
            let resultImage: UIImage

            if image.size.width > maxDimension || image.size.height > maxDimension {
                let scale = maxDimension / max(image.size.width, image.size.height)
                let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                resultImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                }
            } else {
                resultImage = image
            }

            await MainActor.run {
                self.isProcessingImage = false
                self.annotatingImage = resultImage
            }
        }
    }

    func save() async -> Bool {
        isSaving = true
        saveError = nil
        defer {
            isSaving = false
            isUploading = false
        }

        do {
            if pendingImageData != nil {
                isUploading = true
            }

            let savedImageURL = try await InspectionItemService.saveInspectionItem(
                inspectionId: inspection.id,
                roomId: room.id,
                inventoryItemId: item.id,
                status: status,
                notes: notes,
                existingImageURL: imageURL,
                imageData: pendingImageData,
                shouldRemoveImage: shouldRemoveExistingImage && pendingImageData == nil
            )

            imageURL = savedImageURL
            pendingImageData = nil
            shouldRemoveExistingImage = false
            return true
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
            return false
        }
    }
}
