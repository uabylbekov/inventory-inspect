import Testing
@testable import Snapshots

@Suite("Shared Utility Logic")
struct SharedUtilityLogicTests {
    @Test("Snapshot cache keys use lowercase UUIDs and expected prefixes")
    func snapshotCacheKeysAreStable() {
        let userId = UUID(uuidString: "A6A49E25-4EC0-4F0C-B36A-9B0712D3148A")!
        let inspectionId = UUID(uuidString: "E7D7F343-1FD5-449A-90FE-00116E7A8AAB")!
        let olderId = UUID(uuidString: "1DB4CFC4-68BF-4F10-BC3F-D1EF9E69AA8F")!
        let newerId = UUID(uuidString: "3D374B66-F375-41D6-9F1E-C507A0C9F69C")!

        #expect(SnapshotCacheKey.properties(for: userId) == "properties-a6a49e25-4ec0-4f0c-b36a-9b0712d3148a")
        #expect(SnapshotCacheKey.inspectionHub(for: inspectionId) == "inspection-hub-e7d7f343-1fd5-449a-90fe-00116e7a8aab")
        #expect(
            SnapshotCacheKey.comparisonReport(older: olderId, newer: newerId)
                == "comparison-report-1db4cfc4-68bf-4f10-bc3f-d1ef9e69aa8f-3d374b66-f375-41d6-9f1e-c507a0c9f69c"
        )
    }

    @Test("Export filenames sanitize whitespace and punctuation")
    func exportFilenamesAreSanitized() {
        let fileName = ExportFileNameBuilder.pdfFileName(
            prefix: "Inspection Report",
            parts: [" Main / House ", "Kitchen & Dining", ""]
        )

        #expect(matches(fileName, pattern: #"^Inspection_Report_Main_House_Kitchen_Dining_\d{8}_\d{6}\.pdf$"#))
    }

    @Test("Inspection type formatting uses friendly labels")
    func inspectionTypeFormatting() {
        #expect(AppFormatter.formatInspectionType("move-in") == "Move-In")
        #expect(AppFormatter.formatInspectionType("move-out") == "Move-Out")
        #expect(AppFormatter.formatInspectionType("routine") == "Routine")
        #expect(AppFormatter.formatInspectionType("custom follow up") == "Custom Follow Up")
    }

    @Test("Date parsing supports both ISO formats")
    func appFormatterParsesDates() {
        #expect(AppFormatter.parseDate("2026-03-13T18:45:12.123Z") != nil)
        #expect(AppFormatter.parseDate("2026-03-13T18:45:12Z") != nil)
    }

    @Test("Invalid formatted dates are passed through untouched")
    func invalidDateFormattingFallsBackToOriginalValue() {
        #expect(AppFormatter.formatDate("not-a-date") == "not-a-date")
    }

    @Test("PropertyUI returns expected SF Symbols for property and room types")
    func propertyUIIcons() {
        #expect(PropertyUI.icon(for: "Apartment") == "building.2.fill")
        #expect(PropertyUI.icon(for: "Unknown") == "building.2.crop.circle")
        #expect(PropertyUI.roomIcon(for: "Bedroom") == "bed.double.fill")
        #expect(PropertyUI.roomIcon(for: nil) == "square.split.bottomrightquarter")
    }

    @Test("StatusUI returns expected symbols for common statuses")
    func statusUIIcons() {
        #expect(StatusUI.icon(for: "present") == "checkmark.circle.fill")
        #expect(StatusUI.icon(for: "in_progress") == "clock.fill")
        #expect(StatusUI.icon(for: "issues") == "exclamationmark.triangle.fill")
        #expect(StatusUI.icon(for: "unknown") == "circle")
    }

    @Test("Photo attachment error includes current usage and limit")
    func photoAttachmentErrorDescription() {
        let error = SnapshotsAccessManager.PhotoAttachmentError.photoLimitReached(used: 151, limit: 150)

        #expect(error.errorDescription == "Photo limit reached (151/150). Upgrade your plan to save more evidence.")
    }
}
