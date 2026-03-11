# Inspections and Reports

## Why this feature exists

Inspections are the core product action. Everything else in Snapshots exists to make inspections repeatable, collaborative, and exportable. This is the most important feature area for onboarding engineers and testers.

## Main files

- [`Snapshots/Views/Tabs/InspectionsView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Tabs/InspectionsView.swift)
- [`Snapshots/ViewModels/InspectionsViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/InspectionsViewModel.swift)
- [`Snapshots/Views/Team/StartInspectionSheet.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Team/StartInspectionSheet.swift)
- [`Snapshots/ViewModels/StartInspectionViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/StartInspectionViewModel.swift)
- [`Snapshots/Views/Inspections/InspectionHubView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Inspections/InspectionHubView.swift)
- [`Snapshots/ViewModels/InspectionHubViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/InspectionHubViewModel.swift)
- [`Snapshots/Views/Inspections/InspectionItemDetailView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Inspections/InspectionItemDetailView.swift)
- [`Snapshots/Views/Inspections/InspectionReportView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Inspections/InspectionReportView.swift)
- [`Snapshots/ViewModels/InspectionReportViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/InspectionReportViewModel.swift)
- [`Snapshots/Views/Inspections/ComparisonReportView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Inspections/ComparisonReportView.swift)
- [`Snapshots/Utilities/PDFReportGenerator.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Utilities/PDFReportGenerator.swift)

## Inspection lifecycle

An inspection typically moves through these states:

- `in_progress`
- `completed`
- `cancelled`

The inspections list groups records by those statuses. In-progress inspections open the live hub. Completed inspections open the report view. Cancelled inspections can be reopened.

## Starting an inspection

Starting an inspection requires:

- a property
- rooms on that property
- inventory items in those rooms

If the property template is incomplete, the inspection experience will be shallow or blocked. This is why property setup and inspections should always be tested together.

## Inspection hub behavior

The inspection hub is a room-by-room walkthrough driven by the property template.

It calculates:

- total inventory items
- inspected items
- percent complete
- per-room progress

Completion is only allowed when:

- the property has at least one inventory item
- every room with items is fully inspected

An empty property cannot be completed. That rule is intentional in `InspectionHubViewModel.allRoomsComplete`.

## Item-level inspection behavior

For each inventory item, the inspector records a status. The report layer later groups those records into:

- anomalies
- resolved issues
- present and intact items

Optional notes and images enrich the record and become part of the report and PDF output.

## Realtime collaboration

The inspection hub subscribes to `inspection_items` changes filtered to the active inspection. When another device updates an item, the hub reloads data so progress and statuses remain current.

This means two-device QA is important for this feature area.

## Cancellation and deletion

While in progress, an inspection can be:

- cancelled with an optional reason
- permanently deleted

These are separate outcomes and should stay separate in the UI and data model. Cancellation preserves history. Deletion removes it.

## Report behavior

The report screen is the post-inspection summary. It surfaces:

- inspection metadata
- anomaly count
- resolved issue count
- present and intact count
- notes
- attached evidence images

The report also supports:

- resolving issues from the report screen
- exporting a PDF
- launching comparison selection

## PDF generation expectations

PDF output is a product surface, not a developer-only convenience. It must preserve:

- property identity
- inspection metadata
- room and item grouping
- issue statuses
- images
- tier-dependent branding

Any work that touches branding, reports, or image handling should include PDF verification.

## Comparison flows

The comparison flow lets users select another inspection and view change-oriented output. This is useful for verifying issue resolution over time and should be tested with at least one completed inspection pair where item states differ.

## Tester checklist

- Start an inspection on a fully configured property.
- Verify progress updates as items are inspected.
- Confirm rooms show completion state correctly.
- Attempt completion before all rooms are done and confirm it is blocked.
- Complete the inspection and confirm it moves to the completed group.
- Cancel an inspection and confirm it moves to the cancelled group.
- Reopen a cancelled inspection and confirm it returns to active workflows.
- Add notes and evidence images and verify they render in the report.
- Export a PDF and verify filename, content, and branding.
- Compare two completed inspections and verify differences make sense.

## Edge cases to watch

- Property has rooms but zero inventory items.
- Another user updates inspection items while the current user is on the hub.
- Deleting or editing rooms or inventory during an active inspection.
- Report generation with missing images or stale URLs.
- A resolved issue still appearing as an anomaly after refresh.
