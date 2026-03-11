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
            List {
                if isLoading {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if let error = errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("common.try_again") {
                                Task { await fetchInspections() }
                            }
                        }
                    }
                } else if inspections.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "compare_select.no_history_title",
                            systemImage: "clock.badge.exclamationmark",
                            description: Text("compare_select.no_history_message")
                        )
                    }
                } else {
                    ForEach(inspections) { inspection in
                        NavigationLink {
                            ComparisonReportView(base: inspection, current: currentInspection)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(AppFormatter.formatInspectionType(inspection.inspection_type).capitalized)
                                Text(AppFormatter.formatDate(inspection.completed_at ?? inspection.started_at))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("compare_select.title")
            .applyInlineNavigationTitleIfSupported()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
            .task { await fetchInspections() }
        }
    }
    
    private func fetchInspections() async {
        isLoading = true
        do {
            let fetched = try await InspectionDataService.loadCompletedInspections(
                for: currentInspection.property_id,
                excluding: currentInspection.id
            )
            
            self.inspections = fetched
        } catch is CancellationError {
            isLoading = false
            return
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private extension View {
    @ViewBuilder
    func applyInlineNavigationTitleIfSupported() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }
}
