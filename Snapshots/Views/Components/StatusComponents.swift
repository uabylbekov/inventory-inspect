import SwiftUI

struct StatusUI {
    static func color(for status: String) -> Color {
        switch status.lowercased() {
        case "present": return .green
        case "missing": return .orange
        case "damaged": return .red
        case "resolved": return .blue
        case "completed": return .green
        case "in_progress": return .blue
        case "cancelled": return .secondary
        case "stale": return .orange
        case "issues": return .red
        default: return .gray
        }
    }
    
    static func icon(for status: String) -> String {
        switch status.lowercased() {
        case "present": return "checkmark.circle.fill"
        case "missing": return "xmark.circle.fill"
        case "damaged": return "exclamationmark.triangle.fill"
        case "resolved": return "checkmark.seal.fill"
        case "completed": return "checkmark.circle.fill"
        case "in_progress": return "clock.fill"
        case "cancelled": return "xmark.circle.fill"
        case "stale": return "clock.badge.exclamationmark.fill"
        case "issues": return "exclamationmark.triangle.fill"
        default: return "circle"
        }
    }
}

// MARK: - Plan Badge

struct PlanBadge: View {
    @Environment(SnapshotsAccessManager.self) private var accessManager

    private var label: String {
        if accessManager.isDirectSubscriberEnterprise { return "ENTERPRISE" }
        if accessManager.isDirectSubscriber { return "PRO" }
        return ""
    }

    private var color: Color {
        accessManager.isDirectSubscriberEnterprise ? .purple : .accentColor
    }

    var body: some View {
        if accessManager.isDirectSubscriber {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(0.5)
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(color.gradient))
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized.replacingOccurrences(of: "_", with: " "))
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(StatusUI.color(for: status))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(StatusUI.color(for: status).opacity(0.12))
            .clipShape(Capsule())
    }
}
// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)
        }
    }
}
