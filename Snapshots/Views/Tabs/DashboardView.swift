import SwiftUI
import Supabase

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var showingStartInspection = false
    @State private var joinedInspection: InspectionModel?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Spacer()
                        Spacer()
                        VStack {
                            if viewModel.isLoading && viewModel.activeInspections.isEmpty && viewModel.properties.isEmpty {
                                Text("0").font(.title.bold()).redacted(reason: .placeholder)
                            } else {
                                Text("\(viewModel.activeInspections.count)").font(.title.bold())
                            }
                            Text("Active Inspections")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        Spacer()
                        Divider()
                        Spacer()
                        VStack {
                            if viewModel.isLoading && viewModel.recentIssues.isEmpty && viewModel.properties.isEmpty {
                                Text("0").font(.title.bold()).redacted(reason: .placeholder)
                            } else {
                                Text("\(viewModel.recentIssues.count)").font(.title.bold())
                            }
                            Text("Inspection Alerts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Quick Actions") {
                    Button(action: { showingStartInspection = true }) {
                        Label("New Inspection", systemImage: "plus.viewfinder")
                    }
                }
                
                Section("Active Inspections") {
                    if viewModel.isLoading && viewModel.activeInspections.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    } else if viewModel.activeInspections.isEmpty {
                        Text("No active inspections")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.activeInspections) { inspection in
                            NavigationLink {
                                InspectionHubView(inspection: inspection.toInspectionModel)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(inspection.propertyName)
                                        .font(.headline)
                                    Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section("Priority Alerts") {
                    if viewModel.isLoading && viewModel.recentIssues.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    } else if viewModel.recentIssues.isEmpty {
                        Text("System Clear")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.recentIssues) { issue in
                            NavigationLink {
                                if issue.inspections.status == "in_progress" {
                                    InspectionHubView(inspection: issue.inspections.toModel)
                                } else {
                                    InspectionReportView(inspection: issue.inspections.toModel)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(issue.itemName)
                                        .font(.headline)
                                    Text(issue.propertyName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    StatusBadge(status: issue.status)
                                }
                            }
                        }
                    }
                }
            }
            .animation(.default, value: viewModel.isLoading)
            .navigationTitle("Dashboard")
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
                        // Fetch full inspection model before navigating
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
}
