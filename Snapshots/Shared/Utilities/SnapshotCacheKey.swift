import Foundation

enum SnapshotCacheKey {
    static func properties(for userId: UUID) -> String {
        "properties-\(userId.uuidString.lowercased())"
    }

    static func propertyDetail(for propertyId: UUID) -> String {
        "property-detail-\(propertyId.uuidString.lowercased())"
    }

    static func inspections(for userId: UUID) -> String {
        "inspections-\(userId.uuidString.lowercased())"
    }

    static func inspectionProperties(for userId: UUID) -> String {
        "inspection-properties-\(userId.uuidString.lowercased())"
    }

    static func inspectionHub(for inspectionId: UUID) -> String {
        "inspection-hub-\(inspectionId.uuidString.lowercased())"
    }

    static func inspectionReport(for inspectionId: UUID) -> String {
        "inspection-report-\(inspectionId.uuidString.lowercased())"
    }

    static func comparisonReport(older: UUID, newer: UUID) -> String {
        "comparison-report-\(older.uuidString.lowercased())-\(newer.uuidString.lowercased())"
    }
}
