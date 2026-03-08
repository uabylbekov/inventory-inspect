import SwiftUI
import Supabase

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var showingStartInspection = false
    @State private var joinedInspection: InspectionModel?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Header & Greeting
                    headerSection
                    
                    // MARK: - Metric Cards
                    metricsGrid
                    
                    // MARK: - Quick Actions
                    quickActionsSection
                    
                    // MARK: - Sections
                    if !viewModel.activeInspections.isEmpty {
                        activeInspectionsSection
                    }
                    
                    priorityAlertsSection
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NotificationBellView()
                }
            }
            .refreshable {
                await viewModel.fetchData()
            }
            .task {
                await viewModel.fetchData()
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
            .sheet(isPresented: $showingStartInspection) {
                StartInspectionSheet()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.title2.bold())
            Text(subtitleText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private var metricsGrid: some View {
        HStack(spacing: 16) {
            MetricCard(
                title: "Active",
                value: "\(viewModel.activeInspections.count)",
                subtitle: "Inspections",
                icon: "clock.badge.checkmark.fill",
                color: .blue,
                isLoading: viewModel.isLoading && viewModel.activeInspections.isEmpty
            )
            
            MetricCard(
                title: "Alerts",
                value: "\(viewModel.recentIssues.count)",
                subtitle: "Issues Found",
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                isLoading: viewModel.isLoading && viewModel.recentIssues.isEmpty
            )
        }
        .padding(.horizontal)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.title3.bold())
                .padding(.horizontal)
            
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                showingStartInspection = true
            }) {
                Label("Start Inspection", systemImage: "plus.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
        }
    }
    
    private var activeInspectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Inspections")
                .font(.title3.bold())
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.activeInspections) { inspection in
                        NavigationLink {
                            InspectionHubView(inspection: inspection.toInspectionModel)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "house.fill")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color.accentColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    Text(inspection.propertyName)
                                        .font(.headline)
                                        .lineLimit(1)
                                }

                                Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .padding()
                            .frame(width: 180, alignment: .leading)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
    
    private var priorityAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Priority Alerts")
                    .font(.title3.bold())
                Spacer()
                if !viewModel.recentIssues.isEmpty {
                    Text("\(viewModel.recentIssues.count)")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            
            if viewModel.isLoading && viewModel.recentIssues.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if viewModel.recentIssues.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "shield.checkmark.fill")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.green)
                    Text("System Clear")
                        .font(.headline)
                    Text("No outstanding damaged or missing items.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.recentIssues) { issue in
                        NavigationLink {
                            if issue.inspections.status == "in_progress" {
                                InspectionHubView(inspection: issue.inspections.toModel)
                            } else {
                                InspectionReportView(inspection: issue.inspections.toModel)
                            }
                        } label: {
                            DashboardIssueRow(issue: issue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning" }
        if hour < 17 { return "Good Afternoon" }
        return "Good Evening"
    }

    private var subtitleText: String {
        if viewModel.properties.isEmpty { return "Welcome! Let's get started." }
        if !viewModel.recentIssues.isEmpty {
            let count = viewModel.recentIssues.count
            return "\(count) issue\(count == 1 ? "" : "s") need\(count == 1 ? "s" : "") your attention."
        }
        if !viewModel.activeInspections.isEmpty {
            let count = viewModel.activeInspections.count
            return "\(count) inspection\(count == 1 ? "" : "s") currently in progress."
        }
        return "All clear. Your portfolio is healthy."
    }
}

// MARK: - Helper Components

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    var isLoading: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(color)
                Spacer()
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if isLoading {
                    Text("00").font(.system(.title, design: .rounded).bold()).redacted(reason: .placeholder)
                } else {
                    Text(value)
                        .font(.system(.title, design: .rounded).bold())
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct DashboardIssueRow: View {
    let issue: DashboardViewModel.DashboardIssue
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            if let imgStr = issue.image_url, let url = URL(string: imgStr) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemGray5))
                        .frame(width: 60, height: 60)
                        .overlay(ProgressView().scaleEffect(0.8))
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(PropertyUI.roomColor(for: issue.property_rooms.room_type).opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: PropertyUI.roomIcon(for: issue.property_rooms.room_type))
                            .foregroundColor(PropertyUI.roomColor(for: issue.property_rooms.room_type))
                            .symbolRenderingMode(.hierarchical)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(issue.itemName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(issue.status.capitalized)
                        .font(.caption.bold())
                        .foregroundColor(issue.status == "damaged" ? .red : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(issue.status == "damaged" ? Color.red.opacity(0.12) : Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Text(issue.propertyName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(issue.roomName)
                    .font(.footnote)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
    
