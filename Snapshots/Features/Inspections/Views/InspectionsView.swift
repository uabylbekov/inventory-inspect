import SwiftUI
import Supabase

struct InspectionsView: View {
    @State private var viewModel = InspectionsViewModel()
    @Bindable private var notificationManager = NotificationManager.shared
    
    @State private var showDeleteAlert = false
    @State private var inspectionToDelete: InspectionModel? = nil
    @State private var showingCalendar = false

    private var activeInspections: [InspectionModel] {
        viewModel.filteredInspections.filter { $0.status == "in_progress" }
    }

    private var completedInspections: [InspectionModel] {
        viewModel.filteredInspections.filter { $0.status == "completed" }
    }

    private var cancelledInspections: [InspectionModel] {
        viewModel.filteredInspections.filter { $0.status == "cancelled" }
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            List {
                Section {
                    filterHeader
                }

                inspectionBody
            }
            .applyInspectionsListStyle()
            .navigationTitle("inspections.title")
            .applyLargeNavigationTitleIfSupported()
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    NotificationBellView()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        viewModel.showingStartInspection = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("inspections.add")
                        }
                    }
                }
            }
            .refreshable {
                async let fetchI: () = self.viewModel.fetchInspections(showLoadingState: false)
                async let fetchP: () = self.viewModel.fetchProperties()
                _ = await (fetchI, fetchP)
            }
            .task {
                async let fetchI: () = self.viewModel.fetchInspections()
                async let fetchP: () = self.viewModel.fetchProperties()
                _ = await (fetchI, fetchP)
            }
            .sheet(isPresented: $viewModel.showingStartInspection) {
                StartInspectionSheet(preloadedProperties: viewModel.properties) {
                    Task { await viewModel.fetchInspections(showLoadingState: false) }
                }
            }
            .navigationDestination(item: $notificationManager.joiningInspection) { inspection in
                InspectionHubView(inspection: inspection)
            }
            .onReceive(NotificationCenter.default.publisher(for: AppFormatter.joinInspectionNotification)) { output in
                if let id = output.object as? UUID {
                    Task { await notificationManager.handleJoinRequest(id: id) }
                }
            }
            .alert("notifications.join_error", isPresented: Binding<Bool>(get: { notificationManager.joinError != nil }, set: { if !$0 { notificationManager.joinError = nil } })) {
                Button("common.ok") { notificationManager.joinError = nil }
            } message: {
                Text(notificationManager.joinError ?? String(localized: "common.unknown_error"))
            }
            .alert("inspections.delete_title", isPresented: $showDeleteAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("common.delete", role: .destructive) {
                    if let toDelete = inspectionToDelete {
                        Task { await viewModel.deleteInspection(toDelete) }
                    }
                }
            } message: {
                Text("inspections.delete_message")
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var inspectionBody: some View {
        if !viewModel.hasLoadedInitialState {
            Section {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } else if viewModel.isLoading && viewModel.inspections.isEmpty {
            Section {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } else if viewModel.filteredInspections.isEmpty {
            Section {
                ContentUnavailableView(
                    "inspections.empty.title",
                    systemImage: "checklist",
                    description: Text(viewModel.isFilteringByDate ? "inspections.empty.filtered" : "inspections.empty.all")
                )
            }
        } else {
            if !activeInspections.isEmpty {
                inspectionGroup(title: String(localized: "inspections.group.active"), inspections: activeInspections)
            }

            if !completedInspections.isEmpty {
                inspectionGroup(title: String(localized: "inspections.group.completed"), inspections: completedInspections)
            }

            if !cancelledInspections.isEmpty {
                inspectionGroup(title: String(localized: "inspections.group.cancelled"), inspections: cancelledInspections)
            }
        }
    }

    private var filterHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            filterDateControl

            if viewModel.isFilteringByDate {
                Button("inspections.filter.clear") {
                    viewModel.isFilteringByDate = false
                    viewModel.selectedDate = Date()
                }
            }
        }
    }

    @ViewBuilder
    private var filterDateControl: some View {
#if os(macOS)
                Button {
                    showingCalendar = true
                } label: {
                    LabeledContent("inspections.filter.show_records_for") {
                        Text(dateLabel(for: viewModel.selectedDate))
                            .foregroundStyle(.primary)
                    }
                }
        .buttonStyle(.plain)
        .popover(isPresented: $showingCalendar, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("inspections.filter.show_records_for")
                    .font(.headline)

                DatePicker(
                    "",
                    selection: $viewModel.selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                HStack {
                    Button("Today") {
                        viewModel.selectedDate = Date()
                        viewModel.isFilteringByDate = false
                    }

                    Spacer()

                    Button("Done") {
                        showingCalendar = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(width: 320)
        }
#else
        DatePicker("inspections.filter.show_records_for", selection: $viewModel.selectedDate, displayedComponents: .date)
#endif
    }

    private func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    @ViewBuilder
    private func inspectionGroup(title: String, inspections: [InspectionModel]) -> some View {
        Section(title) {
            ForEach(inspections) { inspection in
                let property = viewModel.properties.first(where: { $0.id == inspection.property_id })
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
                        propertyName: property?.name ?? String(localized: "property.unknown"),
                        propertyAddress: property?.address_line1 ?? String(localized: "property.no_address"),
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
                            Label("common.delete", systemImage: "trash")
                        }
                    }
                    
                    if inspection.status == "in_progress" {
                        Button {
                            Task { await viewModel.cancelInspection(inspection) }
                        } label: {
                            Label("common.cancel", systemImage: "xmark.circle")
                        }
                        .tint(.orange)
                    }
                }
                .swipeActions(edge: .leading) {
                    if inspection.status == "cancelled" {
                        Button {
                            Task { await viewModel.reopenInspection(inspection) }
                        } label: {
                            Label("inspections.reopen", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                    }
                }
                .contextMenu {
                    if inspection.status == "in_progress" {
                        Button {
                            Task { await viewModel.cancelInspection(inspection) }
                        } label: {
                            Label("inspections.cancel_walk", systemImage: "xmark.circle")
                        }
                    } else if inspection.status == "cancelled" {
                        Button {
                            Task { await viewModel.reopenInspection(inspection) }
                        } label: {
                            Label("inspections.reopen", systemImage: "arrow.uturn.backward")
                        }
                    }
                    
                    if inspection.status != "completed" {
                        Divider()
                        
                        Button(role: .destructive) {
                            inspectionToDelete = inspection
                            showDeleteAlert = true
                        } label: {
                            Label("inspections.delete_forever", systemImage: "trash")
                        }
                    }
                }
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
        }
    }

}

private extension View {
    @ViewBuilder
    func applyLargeNavigationTitleIfSupported() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
#else
        self
#endif
    }

    @ViewBuilder
    func applyInspectionsListStyle() -> some View {
#if os(macOS)
        self.listStyle(.inset(alternatesRowBackgrounds: true))
#else
        self
#endif
    }
}

// MARK: - Inspection Row

struct InspectionRow: View {
    let inspection: InspectionModel
    let propertyName: String
    let propertyAddress: String
    let anomalyCount: Int
    var resolvedCount: Int
    
    private var isActive: Bool { inspection.status == "in_progress" }
    private var hasIssues: Bool { anomalyCount > 0 && !isActive }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(propertyName)
                    .lineLimit(1)

                if isActive {
                    Spacer()
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }

            Text(propertyAddress)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Text(AppFormatter.formatDate(isActive ? inspection.started_at : (inspection.completed_at ?? inspection.started_at)))

                if hasIssues {
                    Text("•")
                    Text(String.localizedStringWithFormat(
                        NSLocalizedString("inspections.issue_count", comment: ""),
                        anomalyCount
                    ))
                    .foregroundColor(.orange)
                } else if !isActive && anomalyCount == 0 && resolvedCount > 0 {
                    Text("•")
                    Text("pdf.summary.resolved")
                        .foregroundColor(.blue)
                } else if !isActive && anomalyCount == 0 {
                    Text("•")
                    Text("inspections.cleared")
                        .foregroundColor(.green)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if resolvedCount > 0 && !isActive && anomalyCount > 0 {
                Text("\(resolvedCount) resolved")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
