import Foundation
import Supabase

@Observable @MainActor
final class InspectionsViewModel {
    var inspections: [InspectionModel] = []
    var properties: [PropertyModel] = []
    var anomalyCounts: [UUID: Int] = [:]  // inspection_id -> count of missing/damaged
    var resolvedCounts: [UUID: Int] = [:] // inspection_id -> count of resolved items
    
    var isLoading = false
    var hasLoadedInitialState = false
    var errorMessage: String?
    
    var showingStartInspection = false
    
    var isFilteringByDate = false
    var selectedDate = Date() {
        didSet {
            isFilteringByDate = !Calendar.current.isDateInToday(selectedDate)
        }
    }
    
    var filteredInspections: [InspectionModel] {
        if !isFilteringByDate {
            return inspections
        }
        return inspections.filter { inspection in
            guard let date = AppFormatter.parseDate(inspection.started_at) else { return false }
            return Calendar.current.isDate(date, inSameDayAs: selectedDate)
        }
    }
    
    func fetchInspections(showLoadingState: Bool = true) async {
        if showLoadingState && inspections.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.session
            let fetched = try await InspectionDataService.loadAccessibleInspections(for: session.user.id)
            
            var anomalyCountsDict: [UUID: Int] = [:]
            var resolvedCountsDict: [UUID: Int] = [:]
            
            // Fetch anomaly counts for completed inspections
            let completedIds = fetched.filter { $0.status == "completed" }.map { $0.id }
            if !completedIds.isEmpty {
                let items: [InspectionItemModel] = try await supabase
                    .from("inspection_items")
                    .select()
                    .in("inspection_id", values: completedIds.map { $0.uuidString.lowercased() })
                    .neq("status", value: "present") // Get everything that wasn't "present"
                    .execute()
                    .value

                for item in items {
                    if item.status == "resolved" {
                        resolvedCountsDict[item.inspection_id, default: 0] += 1
                    } else if item.status == "missing" || item.status == "damaged" {
                        anomalyCountsDict[item.inspection_id, default: 0] += 1
                    }
                }
            }

            self.inspections = fetched
            self.anomalyCounts = anomalyCountsDict
            self.resolvedCounts = resolvedCountsDict
            
            self.isLoading = false
            self.hasLoadedInitialState = true
        } catch is CancellationError {
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            self.hasLoadedInitialState = true
        }
    }

    func fetchProperties() async {
        do {
            let session = try await supabase.auth.session
            let fetched = try await PropertyAccessService.loadAccessibleProperties(for: session.user.id)

            self.properties = fetched
        } catch is CancellationError {
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func cancelInspection(_ inspection: InspectionModel) async {
        do {
            try await InspectionWorkflowService.cancelInspection(id: inspection.id, reason: "Cancelled from list")
            if let idx = inspections.firstIndex(where: { $0.id == inspection.id }) {
                inspections[idx].status = "cancelled"
            }
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reopenInspection(_ inspection: InspectionModel) async {
        do {
            try await InspectionWorkflowService.reopenInspection(id: inspection.id)
            if let idx = inspections.firstIndex(where: { $0.id == inspection.id }) {
                inspections[idx].status = "in_progress"
            }
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteInspection(_ inspection: InspectionModel) async {
        do {
            try await InspectionWorkflowService.deleteInspection(id: inspection.id)
            inspections.removeAll { $0.id == inspection.id }
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
