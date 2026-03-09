import Foundation
import Observation
import Supabase
import SwiftUI

@Observable @MainActor
class DashboardViewModel {
    var properties: [PropertyModel] = []
    var propertiesCount: Int { properties.count }
    var activeInspections: [InspectionWithProperty] = []
    var recentIssues: [DashboardIssue] = []
    var isLoading = false
    var errorMessage: String?
    
    struct InspectionWithProperty: Identifiable, Codable {
        let id: UUID
        let inspection_type: String
        let status: String
        let started_at: String
        let properties: PropertyModel
        
        var propertyName: String { properties.name }
        
        var toInspectionModel: InspectionModel {
            InspectionModel(
                id: id,
                property_id: properties.id,
                inspector_id: properties.owner_id, // fallback to owner if not specified
                inspection_type: inspection_type,
                status: status,
                notes: nil,
                started_at: started_at,
                completed_at: nil,
                cancellation_reason: nil
            )
        }
    }
    
    struct DashboardIssue: Identifiable, Codable {
        let id: UUID
        let status: String
        let image_url: String?
        let updated_at: String
        let room_inventory_items: NameReference
        let property_rooms: RoomReference
        let inspections: InspectionDetail
        
        struct NameReference: Codable {
            let name: String
        }

        struct RoomReference: Codable {
            let name: String
            let room_type: String?
        }
        
        struct InspectionDetail: Codable {
            let id: UUID
            let property_id: UUID
            let inspector_id: UUID
            let inspection_type: String
            let status: String
            let notes: String?
            let started_at: String
            let completed_at: String?
            let cancellation_reason: String?
            let properties: PropertyModel
            
            var toModel: InspectionModel {
                InspectionModel(
                    id: id,
                    property_id: property_id,
                    inspector_id: inspector_id,
                    inspection_type: inspection_type,
                    status: status,
                    notes: notes,
                    started_at: started_at,
                    completed_at: completed_at,
                    cancellation_reason: cancellation_reason
                )
            }
        }
        
        var itemName: String { room_inventory_items.name }
        var roomName: String { property_rooms.name }
        var propertyName: String { inspections.properties.name }
    }
    
    func fetchData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Fetch properties count
            let properties: [PropertyModel] = try await supabase
                .from("properties")
                .select()
                .execute()
                .value
            self.properties = properties
            
            // 2. Fetch active inspections
            self.activeInspections = try await supabase
                .from("inspections")
                .select("id, inspection_type, status, started_at, properties!inner(*)")
                .eq("status", value: "in_progress")
                .order("started_at", ascending: false)
                .limit(5)
                .execute()
                .value
            
            // 3. Fetch recent issues (damaged or missing)
            // We want items from the LAST 30 days that aren't 'present'
            self.recentIssues = try await supabase
                .from("inspection_items")
                .select("""
                    id, 
                    status, 
                    image_url, 
                    updated_at,
                    room_inventory_items!inner(name),
                    property_rooms!inner(name, room_type),
                    inspections!inner(
                        *,
                        properties!inner(*)
                    )
                """)
                .in("status", values: ["damaged", "missing"])
                .order("updated_at", ascending: false)
                .limit(10)
                .execute()
                .value
            
        } catch is CancellationError {
            isLoading = false
            return
        } catch {
            print("Dashboard fetch error: \(error)")
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }
    
}

