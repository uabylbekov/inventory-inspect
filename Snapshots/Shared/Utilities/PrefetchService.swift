import Foundation

enum PrefetchService {
    private struct PropertyDetailCachedSnapshot: Codable {
        let property: PropertyModel
        let rooms: [PropertyRoomModel]
        let recentInspections: [InspectionModel]
    }

    private struct InspectionHubCachedSnapshot: Codable {
        let property: PropertyModel?
        let rooms: [PropertyRoomModel]
        let inventoryItems: [RoomInventoryItemModel]
        let inspectionItems: [InspectionItemModel]
    }

    private struct InspectionReportCachedSnapshot: Codable {
        let property: PropertyModel?
        let inspectorName: String?
        let anomalies: [ReportItem]
        let presentItems: [ReportItem]
        let resolvedItems: [ReportItem]
    }

    private struct ComparisonReportCachedSnapshot: Codable {
        let property: PropertyModel?
        let previousInspectorName: String?
        let currentInspectorName: String?
        let anomalies: [ReportItem]
        let presentItems: [ReportItem]
        let changedItems: [DiffItem]
        let unchangedItems: [DiffItem]
    }

    static func prefetchPropertyDetails(_ properties: [PropertyModel], limit: Int = 3) async {
        let targets = Array(properties.prefix(limit))

        for property in targets {
            do {
                async let propertyTask = PropertyDataService.loadProperty(id: property.id)
                async let snapshotTask = PropertyDataService.loadPropertyDetailSnapshot(propertyId: property.id)
                let refreshedProperty = try await propertyTask
                let snapshot = try await snapshotTask
                await SnapshotCache.shared.save(
                    PropertyDetailCachedSnapshot(
                        property: refreshedProperty,
                        rooms: snapshot.rooms,
                        recentInspections: snapshot.recentInspections
                    ),
                    key: SnapshotCacheKey.propertyDetail(for: property.id)
                )
            } catch {
                // Ignore background warmup failures.
            }
        }
    }

    static func prefetchInspectionDestinations(_ inspections: [InspectionModel], limit: Int = 4) async {
        let targets = Array(inspections.prefix(limit))

        for inspection in targets {
            do {
                if inspection.status == "in_progress" {
                    let snapshot = try await InspectionDataService.loadInspectionHubSnapshot(for: inspection)
                    await SnapshotCache.shared.save(
                        InspectionHubCachedSnapshot(
                            property: snapshot.property,
                            rooms: snapshot.rooms,
                            inventoryItems: snapshot.inventoryItems,
                            inspectionItems: snapshot.inspectionItems
                        ),
                        key: SnapshotCacheKey.inspectionHub(for: inspection.id)
                    )
                } else {
                    let snapshot = try await InspectionDataService.loadReportSnapshot(for: inspection)
                    await SnapshotCache.shared.save(
                        InspectionReportCachedSnapshot(
                            property: snapshot.property,
                            inspectorName: snapshot.inspectorName,
                            anomalies: snapshot.anomalies,
                            presentItems: snapshot.presentItems,
                            resolvedItems: snapshot.resolvedItems
                        ),
                        key: SnapshotCacheKey.inspectionReport(for: inspection.id)
                    )
                }
            } catch {
                // Ignore background warmup failures.
            }
        }
    }

    static func prefetchComparisons(current: InspectionModel, candidates: [InspectionModel], limit: Int = 2) async {
        let targets = Array(candidates.prefix(limit))

        for candidate in targets {
            do {
                let orderedPair = orderedComparisonPair(candidate, current)
                let snapshot = try await InspectionDataService.loadComparisonSnapshot(
                    older: orderedPair.older,
                    newer: orderedPair.newer
                )
                await SnapshotCache.shared.save(
                    ComparisonReportCachedSnapshot(
                        property: snapshot.property,
                        previousInspectorName: snapshot.previousInspectorName,
                        currentInspectorName: snapshot.currentInspectorName,
                        anomalies: snapshot.anomalies,
                        presentItems: snapshot.presentItems,
                        changedItems: snapshot.changedItems,
                        unchangedItems: snapshot.unchangedItems
                    ),
                    key: SnapshotCacheKey.comparisonReport(older: orderedPair.older.id, newer: orderedPair.newer.id)
                )
            } catch {
                // Ignore background warmup failures.
            }
        }
    }

    private static func orderedComparisonPair(_ lhs: InspectionModel, _ rhs: InspectionModel) -> (older: InspectionModel, newer: InspectionModel) {
        let lhsDate = AppFormatter.parseDate(lhs.started_at) ?? Date.distantPast
        let rhsDate = AppFormatter.parseDate(rhs.started_at) ?? Date.distantPast
        return lhsDate <= rhsDate ? (lhs, rhs) : (rhs, lhs)
    }
}
