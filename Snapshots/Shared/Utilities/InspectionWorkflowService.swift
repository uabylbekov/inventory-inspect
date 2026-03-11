import Foundation
import Supabase

enum InspectionWorkflowService {
    static func completeInspection(id: UUID, completedAt: Date = Date()) async throws {
        let params: [String: AnyJSON] = [
            "status": .string("completed"),
            "completed_at": .string(ISO8601DateFormatter().string(from: completedAt))
        ]

        try await supabase
            .from("inspections")
            .update(params)
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }

    static func cancelInspection(id: UUID, reason: String) async throws {
        let params: [String: AnyJSON] = [
            "status": .string("cancelled"),
            "notes": .string(reason)
        ]

        try await supabase
            .from("inspections")
            .update(params)
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }

    static func reopenInspection(id: UUID) async throws {
        try await supabase
            .from("inspections")
            .update(["status": "in_progress"])
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }

    static func deleteInspection(id: UUID) async throws {
        try await supabase
            .from("inspections")
            .delete()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }
}
