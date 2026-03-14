import Testing
@testable import Snapshots

@Suite("Inspection Room Logic")
struct InspectionRoomLogicTests {
    @Test("Room inspection view model initializes with empty state")
    func roomInspectionDefaults() {
        let inspection = makeInspection()
        let room = makeRoom(name: "Bedroom")
        let viewModel = RoomInspectionViewModel(inspection: inspection, room: room)

        #expect(viewModel.inspection.id == inspection.id)
        #expect(viewModel.room.id == room.id)
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.existingRecords.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("StartInspectionViewModel uses preloaded properties without loading state")
    @MainActor
    func startInspectionUsesPreloadedProperties() async {
        let property = makeProperty()
        let viewModel = StartInspectionViewModel(preloadedProperties: [property])

        #expect(viewModel.properties == [property])
        #expect(!viewModel.isLoadingProperties)

        await viewModel.fetchProperties()

        #expect(viewModel.properties == [property])
        #expect(!viewModel.isLoadingProperties)
    }
}
