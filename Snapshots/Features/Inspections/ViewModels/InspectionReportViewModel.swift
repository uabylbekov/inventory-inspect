import Foundation
import Supabase
import SwiftUI

struct ReportItem: Identifiable {
    var id: UUID { inspectionItem.id }
    let inspectionItem: InspectionItemModel
    let inventoryItem: RoomInventoryItemModel
    let room: PropertyRoomModel
}

@Observable @MainActor
final class InspectionReportViewModel {
    let inspection: InspectionModel
    
    var property: PropertyModel?
    var inspectorName: String?
    var anomalies: [ReportItem] = [] // missing or damaged
    var presentItems: [ReportItem] = []
    var resolvedItems: [ReportItem] = [] // fixed issues
    
    var isLoading = false
    var isRefreshing = false
    var isGeneratingPDF = false
    var errorMessage: String?
    
    init(inspection: InspectionModel) {
        self.inspection = inspection
    }
    
    func fetchReportData(showLoadingState: Bool = true) async {
        if showLoadingState {
            isLoading = true
        } else {
            isRefreshing = true
        }
        errorMessage = nil
        defer {
            isLoading = false
            isRefreshing = false
        }
        
        do {
            let snapshot = try await InspectionDataService.loadReportSnapshot(for: inspection)
            self.property = snapshot.property
            self.inspectorName = snapshot.inspectorName
            self.anomalies = snapshot.anomalies
            self.presentItems = snapshot.presentItems
            self.resolvedItems = snapshot.resolvedItems
        } catch is CancellationError {
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func resolveAnomaly(reportItem: ReportItem) async {
        // Find existing index and store local copy for potential fallback
        guard let index = anomalies.firstIndex(where: { $0.id == reportItem.id }) else { return }
        let originalItem = anomalies[index]
        
        var currentName = "unknown user"
        if let user = try? await supabase.auth.session.user {
            if case let .string(fullName) = user.userMetadata["full_name"], !fullName.isEmpty {
                currentName = fullName
            } else {
                currentName = user.email ?? currentName
            }
        }
        let resolvedNotes = "Resolved by \(currentName)"
        
        // Construct resolved version
        let updatedInspectionItem = InspectionItemModel(
            id: originalItem.inspectionItem.id,
            inspection_id: originalItem.inspectionItem.inspection_id,
            room_id: originalItem.inspectionItem.room_id,
            inventory_item_id: originalItem.inspectionItem.inventory_item_id,
            status: "resolved",
            previous_status: originalItem.inspectionItem.status,
            notes: resolvedNotes,
            image_url: originalItem.inspectionItem.image_url,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        let resolvedItem = ReportItem(
            inspectionItem: updatedInspectionItem,
            inventoryItem: originalItem.inventoryItem,
            room: originalItem.room
        )
        
        // 1. Optimistic Update (Immediate Feedback)
        await MainActor.run {
            withAnimation(.spring) {
                anomalies.remove(at: index)
                resolvedItems.append(resolvedItem)
                resolvedItems.sort(by: { $0.room.name < $1.room.name })
            }
        }
        
        do {
            // 2. Perform DB Update
            try await supabase
                .from("inspection_items")
                .update([
                    "status": "resolved",
                    "previous_status": originalItem.inspectionItem.status,
                    "notes": resolvedNotes
                ])
                .eq("id", value: reportItem.inspectionItem.id.uuidString.lowercased())
                .execute()
        } catch {
            print("Error resolving anomaly: \(error)")
            // 3. Fallback on Error
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                withAnimation {
                    resolvedItems.removeAll(where: { $0.id == reportItem.id })
                    anomalies.append(originalItem)
                    anomalies.sort(by: { $0.room.name < $1.room.name })
                }
            }
        }
    }
    
    @MainActor
    func generatePDF() async -> GeneratedPDF? {
        isGeneratingPDF = true
        await Task.yield() // Let SwiftUI render the spinner before blocking
        defer { isGeneratingPDF = false }
        return await InspectionExportService.makeInspectionReportPDF(
            inspection: inspection,
            property: property,
            inspectorName: inspectorName,
            anomalies: anomalies,
            resolvedItems: resolvedItems,
            presentItems: presentItems
        )
    }
}
