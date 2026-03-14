import Testing
@testable import Snapshots

@MainActor
@Suite("Report And Comparison Logic")
struct ReportAndComparisonLogicTests {
    @Test("ComparisonReportViewModel orders older and newer inspections chronologically")
    func comparisonViewModelOrdersInspections() {
        let newer = InspectionModel(
            id: UUID(),
            property_id: UUID(),
            inspector_id: UUID(),
            inspection_type: "routine",
            status: "completed",
            notes: nil,
            started_at: "2026-03-14T12:00:00Z",
            completed_at: "2026-03-14T13:00:00Z",
            cancellation_reason: nil
        )
        let older = InspectionModel(
            id: UUID(),
            property_id: UUID(),
            inspector_id: UUID(),
            inspection_type: "routine",
            status: "completed",
            notes: nil,
            started_at: "2026-03-13T12:00:00Z",
            completed_at: "2026-03-13T13:00:00Z",
            cancellation_reason: nil
        )

        let viewModel = ComparisonReportViewModel(base: newer, current: older)

        #expect(viewModel.older.id == older.id)
        #expect(viewModel.newer.id == newer.id)
    }

    @Test("ReportItem identity follows its inspection item")
    func reportItemIdentity() {
        let inspectionItem = makeInspectionItem(inspectionId: UUID(), roomId: UUID(), inventoryItemId: UUID())
        let reportItem = ReportItem(
            inspectionItem: inspectionItem,
            inventoryItem: makeInventoryItem(roomId: inspectionItem.room_id, name: "Chair"),
            room: makeRoom(name: "Living Room")
        )

        #expect(reportItem.id == inspectionItem.id)
    }

    @Test("DiffItem id changes when comparison-relevant fields change")
    func diffItemIdentityIncludesComparisonFields() {
        let inventoryItemId = UUID()
        let baseline = DiffItem(
            inventoryItemId: inventoryItemId,
            itemName: "Lamp",
            roomName: "Bedroom",
            oldStatus: "present",
            oldNotes: nil,
            oldImage: nil,
            newStatus: "damaged",
            newPreviousStatus: "present",
            newNotes: "Shade cracked",
            newImage: nil
        )
        let changed = DiffItem(
            inventoryItemId: inventoryItemId,
            itemName: "Lamp",
            roomName: "Bedroom",
            oldStatus: "present",
            oldNotes: nil,
            oldImage: nil,
            newStatus: "resolved",
            newPreviousStatus: "damaged",
            newNotes: "Fixed",
            newImage: nil
        )

        #expect(!baseline.id.isEmpty)
        #expect(baseline.id != changed.id)
    }
}
