import SwiftUI
import Supabase

struct InspectionsView: View {
    @State private var viewModel = InspectionsViewModel()
    @Bindable private var notificationManager = NotificationManager.shared
    
    @State private var showDeleteAlert = false
    @State private var inspectionToDelete: InspectionModel? = nil
    
    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            List {
                // MARK: - Filter Header
                Section {
                    HStack {
                        Label("Show records for", systemImage: "calendar")
                        Spacer()
                        DatePicker("", selection: $viewModel.selectedDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    if viewModel.isFilteringByDate {
                        Button(action: {
                            withAnimation { viewModel.isFilteringByDate = false }
                        }) {
                            Label("Clear Filters (Show All)", systemImage: "xmark.circle")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // MARK: - Inspections Content
                if viewModel.isLoading && viewModel.inspections.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                
                inspectionsSection
                
                // MARK: - Add Section
                Section {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        viewModel.showingStartInspection = true
                    }) {
                        Label("New Inspection", systemImage: "plus.circle.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Inspections")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                async let fetchI: () = self.viewModel.fetchInspections()
                async let fetchP: () = self.viewModel.fetchProperties()
                _ = await (fetchI, fetchP)
            }
            .task {
                async let fetchI: () = self.viewModel.fetchInspections()
                async let fetchP: () = self.viewModel.fetchProperties()
                _ = await (fetchI, fetchP)
            }
            .sheet(isPresented: $viewModel.showingStartInspection, onDismiss: {
                Task { await viewModel.fetchInspections() }
            }) {
                StartInspectionSheet()
            }
            .navigationDestination(item: $notificationManager.joiningInspection) { inspection in
                InspectionHubView(inspection: inspection)
            }
            .onReceive(NotificationCenter.default.publisher(for: AppFormatter.joinInspectionNotification)) { output in
                if let id = output.object as? UUID {
                    Task { await notificationManager.handleJoinRequest(id: id) }
                }
            }
            .alert("Join Error", isPresented: Binding<Bool>(get: { notificationManager.joinError != nil }, set: { if !$0 { notificationManager.joinError = nil } })) {
                Button("OK") { notificationManager.joinError = nil }
            } message: {
                Text(notificationManager.joinError ?? "An unknown error occurred.")
            }
            .alert("Delete Inspection?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let toDelete = inspectionToDelete {
                        Task { await viewModel.deleteInspection(toDelete) }
                    }
                }
            } message: {
                Text("This will permanently remove this inspection and all its recorded data. This cannot be undone.")
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var inspectionsSection: some View {
        let active = viewModel.filteredInspections.filter { $0.status == "in_progress" }
        let completed = viewModel.filteredInspections.filter { $0.status == "completed" }
        let cancelled = viewModel.filteredInspections.filter { $0.status == "cancelled" }
        
        if !active.isEmpty {
            inspectionGroup(title: "Active Walks", inspections: active)
        }
        
        if !completed.isEmpty {
            inspectionGroup(title: "Completed", inspections: completed)
        }
        
        if !cancelled.isEmpty {
            inspectionGroup(title: "Cancelled", inspections: cancelled)
        }
    }
    
    @ViewBuilder
    private func inspectionGroup(title: String, inspections: [InspectionModel]) -> some View {
        Section(title) {
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
                    InspectionRow(
                        inspection: inspection,
                        propertyName: propertyName ?? "Unknown Property",
                        anomalyCount: anomalyCount,
                        resolvedCount: resolvedCount
                    )
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if inspection.status != "completed" {
                        Button(role: .destructive) {
                            inspectionToDelete = inspection
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    
                    if inspection.status == "in_progress" {
                        Button {
                            Task { await viewModel.cancelInspection(inspection) }
                        } label: {
                            Label("Cancel", systemImage: "xmark.circle")
                        }
                        .tint(.orange)
                    }
                }
                .swipeActions(edge: .leading) {
                    if inspection.status == "cancelled" {
                        Button {
                            Task { await viewModel.reopenInspection(inspection) }
                        } label: {
                            Label("Reopen", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                    }
                }
                .contextMenu {
                    if inspection.status == "in_progress" {
                        Button {
                            Task { await viewModel.cancelInspection(inspection) }
                        } label: {
                            Label("Cancel Walk", systemImage: "xmark.circle")
                        }
                    } else if inspection.status == "cancelled" {
                        Button {
                            Task { await viewModel.reopenInspection(inspection) }
                        } label: {
                            Label("Reopen", systemImage: "arrow.uturn.backward")
                        }
                    }
                    
                    if inspection.status != "completed" {
                        Divider()
                        
                        Button(role: .destructive) {
                            inspectionToDelete = inspection
                            showDeleteAlert = true
                        } label: {
                            Label("Delete Forever", systemImage: "trash")
                        }
                    }
                }
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
        }
    }
    

}

// MARK: - Inspection Row

struct InspectionRow: View {
    let inspection: InspectionModel
    let propertyName: String
    let anomalyCount: Int
    var resolvedCount: Int
    
    private var isActive: Bool { inspection.status == "in_progress" }
    private var hasIssues: Bool { anomalyCount > 0 && !isActive }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppFormatter.inspectionTypeColor(for: inspection.inspection_type).opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: AppFormatter.inspectionTypeIcon(for: inspection.inspection_type))
                    .foregroundColor(AppFormatter.inspectionTypeColor(for: inspection.inspection_type))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(propertyName)
                        .font(.headline)
                    
                    if isActive {
                        Spacer()
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Text(AppFormatter.formatDate(isActive ? inspection.started_at : (inspection.completed_at ?? inspection.started_at)))
                    
                    if hasIssues {
                        Text("•")
                        Label("\(anomalyCount) Issues", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else if !isActive && anomalyCount == 0 {
                        Text("•")
                        Label("Cleared", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
