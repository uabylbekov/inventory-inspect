import Testing
@testable import Snapshots

@MainActor
@Suite("Inspection List Logic")
struct InspectionListLogicTests {
    @Test("InspectionsViewModel filters inspections by selected day")
    func inspectionDateFiltering() {
        let targetDay = AppFormatter.parseDate("2026-03-13T12:00:00Z")!
        let sameDayCompleted = InspectionModel(
            id: UUID(),
            property_id: UUID(),
            inspector_id: UUID(),
            inspection_type: "routine",
            status: "completed",
            notes: nil,
            started_at: "2026-03-13T08:00:00Z",
            completed_at: "2026-03-13T09:00:00Z",
            cancellation_reason: nil
        )
        let sameDayInProgress = InspectionModel(
            id: UUID(),
            property_id: UUID(),
            inspector_id: UUID(),
            inspection_type: "move-in",
            status: "in_progress",
            notes: nil,
            started_at: "2026-03-13T15:00:00Z",
            completed_at: nil,
            cancellation_reason: nil
        )
        let nextDayInspection = InspectionModel(
            id: UUID(),
            property_id: UUID(),
            inspector_id: UUID(),
            inspection_type: "move-out",
            status: "completed",
            notes: nil,
            started_at: "2026-03-14T10:00:00Z",
            completed_at: "2026-03-14T11:00:00Z",
            cancellation_reason: nil
        )

        let viewModel = InspectionsViewModel()
        viewModel.inspections = [sameDayCompleted, sameDayInProgress, nextDayInspection]
        viewModel.applyDateFilter(targetDay)

        #expect(viewModel.filteredInspections.count == 2)
        #expect(viewModel.filteredInspections.contains(where: { $0.id == sameDayCompleted.id }))
        #expect(viewModel.filteredInspections.contains(where: { $0.id == sameDayInProgress.id }))
        #expect(!viewModel.filteredInspections.contains(where: { $0.id == nextDayInspection.id }))
    }

    @Test("Resetting inspection date filter returns to today")
    func resetDateFilterToToday() {
        let viewModel = InspectionsViewModel()
        let oldDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        viewModel.applyDateFilter(oldDate)

        #expect(!viewModel.isShowingToday)

        viewModel.resetDateFilterToToday()

        #expect(viewModel.isShowingToday)
    }
}
