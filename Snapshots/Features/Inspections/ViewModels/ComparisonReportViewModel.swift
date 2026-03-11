import Foundation
import Supabase
import SwiftUI

@Observable @MainActor
final class ComparisonReportViewModel {
    let older: InspectionModel
    let newer: InspectionModel
    
    var property: PropertyModel?
    var inspectorName: String?
    var anomalies: [ReportItem] = [] // for Newer inspection
    var presentItems: [ReportItem] = [] // for Newer inspection
    var changedItems: [DiffItem] = []
    var unchangedItems: [DiffItem] = []
    
    var isLoading = false
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
    
    func fetchComparison() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await InspectionDataService.loadComparisonSnapshot(older: older, newer: newer)
            self.property = snapshot.property
            self.inspectorName = snapshot.inspectorName
            self.anomalies = snapshot.anomalies
            self.presentItems = snapshot.presentItems
            self.changedItems = snapshot.changedItems
            self.unchangedItems = snapshot.unchangedItems
            isLoading = false
        } catch is CancellationError {
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
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
}
