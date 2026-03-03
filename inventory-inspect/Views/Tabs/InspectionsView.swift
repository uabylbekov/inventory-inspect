import SwiftUI

struct InspectionsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("📋")
                    .font(.system(size: 48))
                Text("No Inspections Yet")
                    .font(.headline)
                Text("Your upcoming and past property inspections will appear here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Inspections")
        }
    }
}

#Preview {
    InspectionsView()
}
