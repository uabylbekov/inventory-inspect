import SwiftUI
import Supabase

struct InspectionsView: View {
    @State private var viewModel = InspectionsViewModel()
    @State private var joinedInspection: InspectionModel?
    
    var body: some View {
        let viewModel = viewModel
        @Bindable var bindable = viewModel
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.inspections.isEmpty {
                    ContentUnavailableView {
                        Label("No Inspections", systemImage: "checklist")
                    } description: {
                        Text("Start your first inspection to track inventory conditions.")
                    } actions: {
                        Button {
                            viewModel.showingStartInspection = true
                        } label: {
                            Label("Start Inspection", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        // Date Filter
                        Section {
                            HStack {
                                Text(viewModel.isFilteringByDate ? "Filtered" : "All Inspections")
                                    .font(.subheadline)
                                    .foregroundColor(viewModel.isFilteringByDate ? .accentColor : .secondary)
                                
                                Spacer()
                                
                                if viewModel.isFilteringByDate {
                                    Button("Clear") {
                                        withAnimation { viewModel.isFilteringByDate = false }
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                }
                                
                                DatePicker("Filter", selection: $bindable.selectedDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .onChange(of: viewModel.selectedDate) { _, _ in
                                        withAnimation { viewModel.isFilteringByDate = true }
                                    }
                            }
                        }
                        
                        // Inspections List
                        let displayList = viewModel.filteredInspections
                        
                        if displayList.isEmpty {
                            Section {
                                VStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.tertiary)
                                    Text("No inspections on this date")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                            }
                        } else {
                            let active = displayList.filter { $0.status == "in_progress" }
                            let completed = displayList.filter { $0.status == "completed" }
                            let cancelled = displayList.filter { $0.status == "cancelled" }
                            let withIssues = completed.filter { (viewModel.anomalyCounts[$0.id] ?? 0) > 0 }
                            let fullyResolved = completed.filter { (viewModel.anomalyCounts[$0.id] ?? 0) == 0 && (viewModel.resolvedCounts[$0.id] ?? 0) > 0 }
                            let perfect = completed.filter { (viewModel.anomalyCounts[$0.id] ?? 0) == 0 && (viewModel.resolvedCounts[$0.id] ?? 0) == 0 }
                            
                            if !active.isEmpty {
                                Section {
                                    ForEach(active) { inspection in
                                        let propertyName = viewModel.properties.first(where: { $0.id == inspection.property_id })?.name
                                        NavigationLink {
                                            InspectionHubView(inspection: inspection)
                                        } label: {
                                            InspectionRowContent(inspection: inspection, propertyName: propertyName, anomalyCount: 0)
                                        }
                                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                Task { await viewModel.deleteInspection(inspection) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                } header: {
                                    Label("Active", systemImage: "pencil.circle.fill")
                                        .font(.headline)
                                }
                            }
                            
                            if !withIssues.isEmpty {
                                Section {
                                    ForEach(withIssues) { inspection in
                                        let propertyName = viewModel.properties.first(where: { $0.id == inspection.property_id })?.name
                                        NavigationLink {
                                            InspectionReportView(inspection: inspection)
                                        } label: {
                                            InspectionRowContent(inspection: inspection, propertyName: propertyName, anomalyCount: viewModel.anomalyCounts[inspection.id] ?? 0)
                                        }
                                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                    }
                                } header: {
                                    Label("Issues Found", systemImage: "exclamationmark.triangle.fill")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            if !fullyResolved.isEmpty {
                                Section {
                                    ForEach(fullyResolved) { inspection in
                                        let propertyName = viewModel.properties.first(where: { $0.id == inspection.property_id })?.name
                                        NavigationLink {
                                            InspectionReportView(inspection: inspection)
                                        } label: {
                                            InspectionRowContent(
                                                inspection: inspection,
                                                propertyName: propertyName,
                                                anomalyCount: 0,
                                                resolvedCount: viewModel.resolvedCounts[inspection.id] ?? 0
                                            )
                                        }
                                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                    }
                                } header: {
                                    Label("Fully Resolved", systemImage: "checkmark.seal.fill")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if !perfect.isEmpty {
                                Section {
                                    ForEach(perfect) { inspection in
                                        let propertyName = viewModel.properties.first(where: { $0.id == inspection.property_id })?.name
                                        NavigationLink {
                                            InspectionReportView(inspection: inspection)
                                        } label: {
                                            InspectionRowContent(inspection: inspection, propertyName: propertyName, anomalyCount: 0)
                                        }
                                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                    }
                                } header: {
                                    Label("Perfect Inspections", systemImage: "checkmark.seal.fill")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            if !cancelled.isEmpty {
                                Section {
                                    ForEach(cancelled) { inspection in
                                        let propertyName = viewModel.properties.first(where: { $0.id == inspection.property_id })?.name
                                        InspectionRowContent(inspection: inspection, propertyName: propertyName, anomalyCount: 0)
                                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                                Button {
                                                    Task { 
                                                        HapticManager.shared.impact(style: .medium)
                                                        await viewModel.reopenInspection(inspection) 
                                                        HapticManager.shared.notification(type: .success)
                                                    }
                                                } label: {
                                                    Label("Reopen", systemImage: "arrow.uturn.backward.circle.fill")
                                                }
                                                .tint(.blue)
                                            }
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                Button(role: .destructive) {
                                                    Task { 
                                                        HapticManager.shared.impact(style: .medium)
                                                        await viewModel.deleteInspection(inspection) 
                                                        HapticManager.shared.notification(type: .success)
                                                    }
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                } header: {
                                    Label("Cancelled", systemImage: "xmark.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .animation(.default, value: viewModel.isLoading)
            .navigationTitle("Inspections")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.showingStartInspection = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("New Inspection")
                        }
                    }
                }
            }
            .sheet(isPresented: $bindable.showingStartInspection, onDismiss: {
                Task { await viewModel.fetchInspections() }
            }) {
                StartInspectionSheet()
            }
            .task {
                async let fetchI: () = viewModel.fetchInspections()
                async let fetchP: () = viewModel.fetchProperties()
                _ = await (fetchI, fetchP)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JoinInspection"))) { output in
                if let id = output.object as? UUID {
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
            .navigationDestination(item: $joinedInspection) { inspection in
                InspectionHubView(inspection: inspection)
            }
            .refreshable {
                async let fetchI: () = viewModel.fetchInspections()
                async let fetchP: () = viewModel.fetchProperties()
                _ = await (fetchI, fetchP)
            }
        }
    }
}

struct InspectionRowContent: View {
    let inspection: InspectionModel
    let propertyName: String?
    let anomalyCount: Int
    var resolvedCount: Int = 0
    
    private var isActive: Bool { inspection.status == "in_progress" }
    private var isCancelled: Bool { inspection.status == "cancelled" }
    private var isResolved: Bool { resolvedCount > 0 && anomalyCount == 0 }
    private var hasIssues: Bool { anomalyCount > 0 }
    
    private var isStale: Bool {
        guard isActive else { return false }
        guard let date = AppFormatter.parseDate(inspection.started_at) else { return false }
        return Date().timeIntervalSince(date) > 24 * 3600 // 24 hours
    }
    
    private var typeIcon: String {
        switch inspection.inspection_type {
        case "check-in": return "sparkles"
        case "check-out": return "house.and.flag"
        case "routine": return "wrench.and.screwdriver"
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
        HStack(spacing: 14) {
            // Type Icon
            Image(systemName: typeIcon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isActive ? typeColor.gradient : Color(UIColor.systemGray4).gradient)
                )
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                        .font(.headline)
                    
                    if let propertyName = propertyName {
                        Text("• \(propertyName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text(AppFormatter.formatDate(isActive ? inspection.started_at : (inspection.completed_at ?? inspection.started_at)))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if isStale {
                        StatusBadge(status: "stale")
                    } else if hasIssues {
                        StatusBadge(status: "damaged")
                    } else if isResolved {
                        StatusBadge(status: "resolved")
                    } else if isCancelled {
                        StatusBadge(status: "cancelled")
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    InspectionsView()
}
