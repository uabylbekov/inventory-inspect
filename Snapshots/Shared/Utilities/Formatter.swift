import Foundation
import SwiftUI

struct AppFormatter {

    // MARK: - Notifications
    static let joinInspectionNotification = NSNotification.Name("JoinInspection")

    // MARK: - Inspection Type UI
    static func inspectionTypeIcon(for type: String) -> String {
        switch type {
        case "move-in": return "door.left.hand.open"
        case "move-out": return "door.right.hand.closed"
        case "routine": return "wrench.adjustable.fill"
        default: return "checklist"
        }
    }

    static func inspectionTypeColor(for type: String) -> Color {
        switch type {
        case "move-in": return .purple
        case "move-out": return .blue
        case "routine": return .orange
        default: return .gray
        }
    }

    // MARK: - Formatting
    static func formatInspectionType(_ type: String) -> String {
        switch type {
        case "move-in": return "Move-In"
        case "move-out": return "Move-Out"
        case "routine": return "Routine"
        default: return type.capitalized
        }
    }
    
    static func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var parsedDate = formatter.date(from: dateString)
        
        if parsedDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            parsedDate = formatter.date(from: dateString)
        }
        
        guard let date = parsedDate else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d, h:mm a"
        return displayFormatter.string(from: date)
    }
    
    static func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}
