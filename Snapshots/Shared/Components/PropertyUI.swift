import SwiftUI

struct PropertyUI {
    static func icon(for propertyType: String) -> String {
        switch propertyType.lowercased() {
        case "apartment": return "building.2.fill"
        case "house": return "house.fill"
        case "condo": return "building.fill"
        case "townhouse": return "house.and.flag.fill"
        default: return "building.2.crop.circle"
        }
    }
    
    static func color(for propertyType: String) -> Color {
        switch propertyType.lowercased() {
        case "apartment": return .blue
        case "house": return .green
        case "condo": return .purple
        case "townhouse": return .orange
        default: return .gray
        }
    }
    
    static func roomIcon(for type: String?) -> String {
        switch type?.lowercased() {
        case "bedroom": return "bed.double.fill"
        case "bathroom": return "shower.fill"
        case "kitchen": return "frying.pan.fill"
        case "living room": return "sofa.fill"
        case "dining room": return "fork.knife"
        case "office": return "desktopcomputer"
        case "outdoor space": return "tree.fill"
        default: return "square.split.bottomrightquarter"
        }
    }
    
    static func roomColor(for type: String?) -> Color {
        switch type?.lowercased() {
        case "bedroom": return .indigo
        case "bathroom": return .cyan
        case "kitchen": return .orange
        case "living room": return .teal
        case "dining room": return .brown
        case "office": return .blue
        case "outdoor space": return .green
        default: return .gray
        }
    }
}
