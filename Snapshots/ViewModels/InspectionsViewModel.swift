import Foundation
import Supabase

@Observable @MainActor
final class InspectionsViewModel {
    var inspections: [InspectionModel] = []
    var properties: [PropertyModel] = []
    var anomalyCounts: [UUID: Int] = [:]  // inspection_id -> count of missing/damaged
    var resolvedCounts: [UUID: Int] = [:] // inspection_id -> count of resolved items
    
    var isLoading = false
    var errorMessage: String?
    
    var showingStartInspection = false
    
    var isFilteringByDate = false
    var selectedDate = Date() {
        didSet {
            isFilteringByDate = true
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
            let fetched: [InspectionModel] = try await supabase
                .from("inspections")
                .select()
                .order("started_at", ascending: false)
                .execute()
                .value
                
            self.inspections = fetched
            
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
                
                var anomalyCountsDict: [UUID: Int] = [:]
                var resolvedCountsDict: [UUID: Int] = [:]
                
                for item in items {
                    if item.status == "resolved" {
                        resolvedCountsDict[item.inspection_id, default: 0] += 1
                    } else if item.status == "missing" || item.status == "damaged" {
                        anomalyCountsDict[item.inspection_id, default: 0] += 1
                    }
                }
                self.anomalyCounts = anomalyCountsDict
                self.resolvedCounts = resolvedCountsDict
            }
            
            self.isLoading = false
        } catch is CancellationError {
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    func fetchProperties() async {
        do {
            let fetched: [PropertyModel] = try await supabase
                .from("properties")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            self.properties = fetched
        } catch is CancellationError {
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func cancelInspection(_ inspection: InspectionModel) async {
        do {
            let params: [String: AnyJSON] = [
                "status": .string("cancelled"),
                "notes": .string("Cancelled from list")
            ]
            try await supabase
                .from("inspections")
                .update(params)
                .eq("id", value: inspection.id.uuidString.lowercased())
                .execute()
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
            try await supabase
                .from("inspections")
                .update(["status": "in_progress"])
                .eq("id", value: inspection.id.uuidString.lowercased())
                .execute()
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
            try await supabase
                .from("inspections")
                .delete()
                .eq("id", value: inspection.id.uuidString.lowercased())
                .execute()
            inspections.removeAll { $0.id == inspection.id }
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
