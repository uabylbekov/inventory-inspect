import Foundation
import Testing
@testable import Snapshots

@MainActor
@Suite("Inspection Progress Logic")
struct InspectionProgressLogicTests {
    @Test("InspectionHubViewModel calculates room progress from inventory coverage")
    func inspectionProgressCalculation() throws {
        let roomA = makeRoom(name: "Kitchen")
        let roomB = makeRoom(name: "Bedroom")
        let itemA1 = makeInventoryItem(roomId: roomA.id, name: "Plate")
        let itemA2 = makeInventoryItem(roomId: roomA.id, name: "Cup")
        let itemB1 = makeInventoryItem(roomId: roomB.id, name: "Lamp")
        let inspection = makeInspection()

        let viewModel = InspectionHubViewModel(inspection: inspection)
        viewModel.rooms = [roomA, roomB]
        viewModel.allInventoryItems = [itemA1, itemA2, itemB1]
        viewModel.inspectionItems = [
            makeInspectionItem(inspectionId: inspection.id, roomId: roomA.id, inventoryItemId: itemA1.id),
            makeInspectionItem(inspectionId: inspection.id, roomId: roomB.id, inventoryItemId: itemB1.id)
        ]

        viewModel.calculateProgress()

        let kitchen = try #require(viewModel.roomProgress(for: roomA.id))
        let bedroom = try #require(viewModel.roomProgress(for: roomB.id))

        #expect(kitchen.progressString == "1/2")
        #expect(kitchen.progressFraction == 0.5)
        #expect(!kitchen.isComplete)

        #expect(bedroom.progressString == "1/1")
        #expect(bedroom.progressFraction == 1.0)
        #expect(bedroom.isComplete)

        #expect(!viewModel.allRoomsComplete)
        #expect(viewModel.inspectionRecord(for: itemA1.id)?.inventory_item_id == itemA1.id)
        #expect(viewModel.inspectionRecord(for: itemA2.id) == nil)
    }

    @Test("Empty rooms count as empty but do not make the inspection completable")
    func emptyRoomsCannotCompleteInspection() throws {
        let room = makeRoom(name: "Empty Room")
        let viewModel = InspectionHubViewModel(inspection: makeInspection())
        viewModel.rooms = [room]
        viewModel.allInventoryItems = []
        viewModel.inspectionItems = []

        viewModel.calculateProgress()

        let progress = try #require(viewModel.roomProgress(for: room.id))
        #expect(progress.progressString == "Empty")
        #expect(progress.progressFraction == 1.0)
        #expect(!viewModel.allRoomsComplete)
    }
}
