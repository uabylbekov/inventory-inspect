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
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
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
            Text(viewModel.properties.isEmpty ? "Welcome! Let's get started." : "Your portfolio is looking healthy.")
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
                .font(.headline)
                .padding(.horizontal)
            
            Button(action: { 
                HapticManager.shared.impact(style: .medium)
                showingStartInspection = true 
            }) {
                HStack {
                    Image(systemName: "plus.viewfinder")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Start New Inspection")
                        .fontWeight(.bold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor.gradient)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal)
        }
    }
    
    private var activeInspectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Inspections")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.activeInspections) { inspection in
                        NavigationLink {
                            InspectionHubView(inspection: inspection.toInspectionModel)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "house.fill")
                                        .foregroundColor(.blue)
                                    Text(inspection.propertyName)
                                        .font(.subheadline.bold())
                                        .lineLimit(1)
                                }
                                
                                Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .padding()
                            .frame(width: 180, alignment: .leading)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
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
                    .font(.headline)
                Spacer()
                if !viewModel.recentIssues.isEmpty {
                    Text("\(viewModel.recentIssues.count)")
                        .font(.caption.bold())
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
                        .foregroundColor(.green)
                    Text("System Clear")
                        .font(.subheadline.bold())
                    Text("No outstanding damaged or missing items.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                    .foregroundColor(color)
                Spacer()
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if isLoading {
                    Text("00").font(.title.bold()).redacted(reason: .placeholder)
                } else {
                    Text(value)
                        .font(.system(.title, design: .rounded).bold())
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
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
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: issue.status == "missing" ? "questionmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(issue.itemName)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Spacer()
                    Text(issue.status.capitalized)
                        .font(.caption2.bold())
                        .foregroundColor(issue.status == "damaged" ? .red : .orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(issue.status == "damaged" ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Text(issue.propertyName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(issue.roomName)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
