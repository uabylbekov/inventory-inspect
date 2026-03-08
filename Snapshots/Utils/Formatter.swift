import Foundation
import SwiftUI

struct AppFormatter {
    static func formatInspectionType(_ type: String) -> String {
        switch type {
        case "check-in": return "Check In"
        case "check-out": return "Check Out"
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
