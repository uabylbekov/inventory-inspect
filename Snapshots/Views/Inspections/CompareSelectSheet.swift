import SwiftUI
import Supabase

struct CompareSelectSheet: View {
    let currentInspection: InspectionModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var inspections: [InspectionModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if inspections.isEmpty {
                    ContentUnavailableView(
                        "No other inspections",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("There are no other completed inspections for this property to use as a snapshot.")
                    )
                } else {
                    List(inspections) { inspection in
                        NavigationLink {
                            ComparisonReportView(base: inspection, current: currentInspection)
                        } label: {
                            HStack(spacing: 16) {
                                // Radio-style indicator (visual only since it navigates on tap)
                                Circle()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.1))
                                            .frame(width: 12, height: 12)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(AppFormatter.formatInspectionType(inspection.inspection_type).capitalized)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Label(
                                        AppFormatter.formatDate(inspection.completed_at ?? inspection.started_at),
                                        systemImage: "calendar"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await fetchInspections() }
        }
    }
    
    private func fetchInspections() async {
        isLoading = true
        do {
            let fetched: [InspectionModel] = try await supabase
                .from("inspections")
                .select()
                .eq("property_id", value: currentInspection.property_id.uuidString.lowercased())
                .eq("status", value: "completed")
                .neq("id", value: currentInspection.id.uuidString.lowercased())
                .order("completed_at", ascending: false)
                .execute()
                .value
            
            self.inspections = fetched
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
