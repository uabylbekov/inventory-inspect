import Foundation
import Supabase
import SwiftUI

@Observable @MainActor
final class ComparisonReportViewModel {
    private struct CachedSnapshot: Codable {
        let property: PropertyModel?
        let inspectorName: String?
        let anomalies: [ReportItem]
        let presentItems: [ReportItem]
        let changedItems: [DiffItem]
        let unchangedItems: [DiffItem]
    }

    private enum CacheConfig {
        static let keyPrefix = "comparison-report"
        static let maxAge: TimeInterval = 5 * 60
    }

    let older: InspectionModel
    let newer: InspectionModel
    
    var property: PropertyModel?
    var inspectorName: String?
    var anomalies: [ReportItem] = [] // for Newer inspection
    var presentItems: [ReportItem] = [] // for Newer inspection
    var changedItems: [DiffItem] = []
    var unchangedItems: [DiffItem] = []
    
    var isLoading = false
    var hasLoadedInitialState = false
    var isGeneratingPDF = false
    var errorMessage: String?
    
    init(base: InspectionModel, current: InspectionModel) {
        // Automatically determine chronological order
        let date1 = AppFormatter.parseDate(base.started_at) ?? Date.distantPast
        let date2 = AppFormatter.parseDate(current.started_at) ?? Date.distantPast
        
        if date1 <= date2 {
            self.older = base
            self.newer = current
        } else {
            self.older = current
            self.newer = base
        }
    }

    func loadInitialData() async {
        if let cachedSnapshot = await SnapshotCache.shared.load(
            CachedSnapshot.self,
            key: Self.cacheKey(older: older.id, newer: newer.id),
            maxAge: CacheConfig.maxAge
        ) {
            apply(snapshot: cachedSnapshot)
        }

        hasLoadedInitialState = true
        await fetchComparison(showLoadingState: changedItems.isEmpty && unchangedItems.isEmpty)
    }
    
    func fetchComparison(showLoadingState: Bool = true) async {
        if showLoadingState {
            isLoading = true
        }
        errorMessage = nil
        do {
            let snapshot = try await InspectionDataService.loadComparisonSnapshot(older: older, newer: newer)
            let cachedSnapshot = CachedSnapshot(
                property: snapshot.property,
                inspectorName: snapshot.inspectorName,
                anomalies: snapshot.anomalies,
                presentItems: snapshot.presentItems,
                changedItems: snapshot.changedItems,
                unchangedItems: snapshot.unchangedItems
            )
            apply(snapshot: cachedSnapshot)
            await SnapshotCache.shared.save(cachedSnapshot, key: Self.cacheKey(older: older.id, newer: newer.id))
            isLoading = false
            hasLoadedInitialState = true
        } catch is CancellationError {
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            hasLoadedInitialState = true
        }
    }

    @MainActor
    func generatePDF() async -> GeneratedPDF {
        isGeneratingPDF = true
        await Task.yield()
        defer { isGeneratingPDF = false }

        return await InspectionExportService.makeComparisonReportPDF(
            older: older,
            newer: newer,
            property: property,
            inspectorName: inspectorName,
            changedItems: changedItems,
            unchangedItems: unchangedItems
        )
    }

    private func apply(snapshot: CachedSnapshot) {
        property = snapshot.property
        inspectorName = snapshot.inspectorName
        anomalies = snapshot.anomalies
        presentItems = snapshot.presentItems
        changedItems = snapshot.changedItems
        unchangedItems = snapshot.unchangedItems
    }

    private static func cacheKey(older: UUID, newer: UUID) -> String {
        SnapshotCacheKey.comparisonReport(older: older, newer: newer)
    }
}
