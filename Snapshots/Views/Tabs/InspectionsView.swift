import SwiftUI
import Supabase

struct InspectionsView: View {
    @State private var viewModel = InspectionsViewModel()
    @State private var joinedInspection: InspectionModel?
    @State private var inspectionToDelete: InspectionModel?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Filter Header
                    filterHeaderSection()
                    
                    // MARK: - Inspections Content
                    if viewModel.isLoading {
                        loadingState
                    } else if viewModel.inspections.isEmpty {
                        emptyState
                    } else {
                        inspectionsSection
                    }
                    
                    Spacer().frame(height: 32)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Inspections")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        viewModel.showingStartInspection = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .symbolRenderingMode(.hierarchical)
                            Text("New Inspection")
                        }
                    }
                }
            }
            .refreshable {
                async let fetchI: () = viewModel.fetchInspections()
                async let fetchP: () = viewModel.fetchProperties()
                _ = await (fetchI, fetchP)
            }
            .task {
                async let fetchI: () = viewModel.fetchInspections()
                async let fetchP: () = viewModel.fetchProperties()
                _ = await (fetchI, fetchP)
            }
            .sheet(isPresented: $viewModel.showingStartInspection, onDismiss: {
                Task { await viewModel.fetchInspections() }
            }) {
                StartInspectionSheet()
            }
            .navigationDestination(item: $joinedInspection) { inspection in
                InspectionHubView(inspection: inspection)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JoinInspection"))) { output in
                if let id = output.object as? UUID {
                    handleJoinNotification(id)
                }
            }
            .alert("Delete Inspection?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { inspectionToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let inspection = inspectionToDelete {
                        Task { await viewModel.deleteInspection(inspection) }
                    }
                    inspectionToDelete = nil
                }
            } message: {
                Text("This will permanently delete this inspection record and all associated data. This cannot be undone.")
            }
        }
    }
    
    // MARK: - Subviews
    
    private func filterHeaderSection() -> some View {
        HStack(spacing: 0) {
            Label(viewModel.isFilteringByDate ? "Filtered View" : "All Records", systemImage: viewModel.isFilteringByDate ? "line.3.horizontal.decrease.circle.fill" : "calendar")
                .font(.subheadline)
                .foregroundColor(viewModel.isFilteringByDate ? .accentColor : .secondary)

            Spacer()

            if viewModel.isFilteringByDate {
                Button("Clear") {
                    withAnimation { viewModel.isFilteringByDate = false }
                }
                .font(.caption.bold())
                .foregroundColor(.red)
                .padding(.trailing, 12)
            }

            DatePicker("", selection: $viewModel.selectedDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .onChange(of: viewModel.selectedDate) { _, _ in
                    withAnimation { viewModel.isFilteringByDate = true }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }
    
    private var inspectionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            let displayList = viewModel.filteredInspections
            
            if displayList.isEmpty {
                noFilteredResultsState
            } else {
                let active = displayList.filter { $0.status == "in_progress" }
                let completed = displayList.filter { $0.status == "completed" }
                let cancelled = displayList.filter { $0.status == "cancelled" }
                
                if !active.isEmpty {
                    inspectionGroup(title: "Active Walks", inspections: active, color: .accentColor)
                }
                
                if !completed.isEmpty {
                    inspectionGroup(title: "Completed", inspections: completed, color: .secondary)
                }
                
                if !cancelled.isEmpty {
                    inspectionGroup(title: "Cancelled", inspections: cancelled, color: .secondary)
                }
            }
        }
    }
    
    private func inspectionGroup(title: String, inspections: [InspectionModel], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(.primary.opacity(0.8))
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(inspections) { inspection in
                    let propertyName = viewModel.properties.first(where: { $0.id == inspection.property_id })?.name
                    let anomalyCount = viewModel.anomalyCounts[inspection.id] ?? 0
                    let resolvedCount = viewModel.resolvedCounts[inspection.id] ?? 0
                    
                    NavigationLink {
                        if inspection.status == "in_progress" {
                            InspectionHubView(inspection: inspection)
                        } else {
                            InspectionReportView(inspection: inspection)
                        }
                    } label: {
                        InspectionCard(
                            inspection: inspection,
                            propertyName: propertyName,
                            anomalyCount: anomalyCount,
                            resolvedCount: resolvedCount
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if inspection.status == "cancelled" {
                            Button {
                                Task { await viewModel.reopenInspection(inspection) }
                            } label: {
                                Label("Reopen", systemImage: "arrow.uturn.backward")
                            }
                        }
                        
                        Button(role: .destructive) {
                            inspectionToDelete = inspection
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete Record", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 48))
                .foregroundColor(.accentColor.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("Ready for Walkthrough?")
                    .font(.headline)
                Text("Start your first property inspection to track item conditions and history.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Start New Inspection") {
                viewModel.showingStartInspection = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.top, 80)
    }
    
    private var noFilteredResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundColor(.secondary.opacity(0.5))
            Text("No records found for this date")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
    
    private func handleJoinNotification(_ id: UUID) {
        Task {
            do {
                let inspection: [InspectionModel] = try await supabase
                    .from("inspections")
                    .select()
                    .eq("id", value: id.uuidString.lowercased())
                    .execute()
                    .value
                
                if let first = inspection.first {
                    await MainActor.run {
                        self.joinedInspection = first
                    }
                }
            } catch {
                print("Error joining: \(error)")
            }
        }
    }
}

// MARK: - Balanced Inspection Card

struct InspectionCard: View {
    let inspection: InspectionModel
    let propertyName: String?
    let anomalyCount: Int
    var resolvedCount: Int = 0
    
    private var isActive: Bool { inspection.status == "in_progress" }
    private var isCancelled: Bool { inspection.status == "cancelled" }
    private var isResolved: Bool { resolvedCount > 0 && anomalyCount == 0 }
    private var hasIssues: Bool { anomalyCount > 0 && !isActive }
    
    private var typeIcon: String {
        switch inspection.inspection_type {
        case "check-in": return "door.left.hand.open"
        case "check-out": return "door.right.hand.closed"
        case "routine": return "wrench.adjustable.fill"
        default: return "checklist"
        }
    }
    
    private var typeColor: Color {
        switch inspection.inspection_type {
        case "check-in": return .purple
        case "check-out": return .blue
        case "routine": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Consistent 60x60 square icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? typeColor.opacity(0.12) : Color.gray.opacity(0.08))
                    .frame(width: 60, height: 60)
                
                Image(systemName: typeIcon)
                    .font(.title3)
                    .foregroundColor(isActive ? typeColor : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                    .font(.headline.bold())
                    .foregroundColor(isActive ? .primary : .secondary)
                
                Text(propertyName ?? "Unknown Property")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text(AppFormatter.formatDate(isActive ? inspection.started_at : (inspection.completed_at ?? inspection.started_at)))
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    if hasIssues {
                        Text("•")
                        Text("\(anomalyCount) Issues")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(.red)
                    } else if isResolved {
                        Text("•")
                        Text("Resolved")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Status Indicator
            if isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: .green.opacity(0.3), radius: 3)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.3))
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
