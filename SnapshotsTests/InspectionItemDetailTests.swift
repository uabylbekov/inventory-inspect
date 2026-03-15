import Foundation
import Testing
@testable import Snapshots

@MainActor
@Suite("Inspection Item Detail Logic")
struct InspectionItemDetailLogicTests {
    @Test("Inspection item detail view model initializes from existing record")
    func initializesFromExistingRecord() {
        let inspection = makeInspection()
        let room = makeRoom(name: "Bedroom")
        let item = makeInventoryItem(roomId: room.id, name: "Lamp")
        let record = InspectionItemModel(
            id: UUID(),
            inspection_id: inspection.id,
            room_id: room.id,
            inventory_item_id: item.id,
            status: "damaged",
            previous_status: "present",
            notes: "Broken shade",
            image_url: "https://example.com/lamp.jpg",
            updated_at: "2026-03-13T00:00:00Z"
        )

        let viewModel = InspectionItemDetailViewModel(
            item: item,
            inspection: inspection,
            room: room,
            property: makeProperty(),
            initialRecord: record
        )

        #expect(viewModel.status == "damaged")
        #expect(viewModel.notes == "Broken shade")
        #expect(viewModel.imageURL == "https://example.com/lamp.jpg")
        #expect(viewModel.pendingImageData == nil)
        #expect(!viewModel.isSaving)
        #expect(!viewModel.isUploading)
        #expect(!viewModel.isProcessingImage)
        #expect(viewModel.saveError == nil)
    }

    @Test("Inspection item detail view model falls back to present state without a record")
    func initializesWithoutExistingRecord() {
        let room = makeRoom(name: "Bathroom")
        let item = makeInventoryItem(roomId: room.id, name: "Mirror")

        let viewModel = InspectionItemDetailViewModel(
            item: item,
            inspection: makeInspection(),
            room: room,
            property: nil,
            initialRecord: nil
        )

        #expect(viewModel.status == "present")
        #expect(viewModel.notes.isEmpty)
        #expect(viewModel.imageURL == nil)
    }

    @Test("Updating status changes local selection")
    func updateStatusChangesValue() {
        let room = makeRoom(name: "Living Room")
        let item = makeInventoryItem(roomId: room.id, name: "Table")
        let viewModel = InspectionItemDetailViewModel(
            item: item,
            inspection: makeInspection(),
            room: room,
            property: nil,
            initialRecord: nil
        )

        viewModel.updateStatus("missing")

        #expect(viewModel.status == "missing")
    }

    @Test("Removing photo clears both local URL and pending data")
    func removePhotoClearsImageState() {
        let inspection = makeInspection()
        let room = makeRoom(name: "Entry")
        let item = makeInventoryItem(roomId: room.id, name: "Key")
        let record = InspectionItemModel(
            id: UUID(),
            inspection_id: inspection.id,
            room_id: room.id,
            inventory_item_id: item.id,
            status: "present",
            previous_status: nil,
            notes: nil,
            image_url: "https://example.com/key.jpg",
            updated_at: "2026-03-13T00:00:00Z"
        )
        let viewModel = InspectionItemDetailViewModel(
            item: item,
            inspection: inspection,
            room: room,
            property: nil,
            initialRecord: record
        )
        viewModel.pendingImageData = Data([1, 2, 3])

        viewModel.removePhoto()

        #expect(viewModel.imageURL == nil)
        #expect(viewModel.pendingImageData == nil)
    }

    @Test("Annotated image data replaces pending data without touching current URL")
    func setAnnotatedImageDataStoresPendingData() {
        let inspection = makeInspection()
        let room = makeRoom(name: "Office")
        let item = makeInventoryItem(roomId: room.id, name: "Desk")
        let record = InspectionItemModel(
            id: UUID(),
            inspection_id: inspection.id,
            room_id: room.id,
            inventory_item_id: item.id,
            status: "present",
            previous_status: nil,
            notes: nil,
            image_url: "https://example.com/desk.jpg",
            updated_at: "2026-03-13T00:00:00Z"
        )
        let viewModel = InspectionItemDetailViewModel(
            item: item,
            inspection: inspection,
            room: room,
            property: nil,
            initialRecord: record
        )
        let data = Data([9, 8, 7])

        viewModel.setAnnotatedImageData(data)

        #expect(viewModel.pendingImageData == data)
        #expect(viewModel.imageURL == "https://example.com/desk.jpg")
    }
}
