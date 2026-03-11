import Foundation
import Supabase

enum PlanUsageService {
    static func loadOwnerPhotoUsage(ownerId: UUID) async throws -> Int {
        let params: [String: AnyJSON] = [
            "p_owner_id": .string(ownerId.uuidString.lowercased())
        ]

        return try await supabase
            .rpc("get_owner_photo_usage", params: params)
            .execute()
            .value
    }
}
