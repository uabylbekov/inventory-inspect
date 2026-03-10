import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @Bindable private var notificationManager = NotificationManager.shared
    @State private var showingStartInspection = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Welcome Section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(greetingText)
                                .font(.headline)
                            PlanBadge()
                        }
                        Text(subtitleText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("settings.plan") {
                    SubscriptionPlanRow()
                }
                
                // MARK: - Priority Alerts
                Section {
                    if viewModel.recentIssues.isEmpty {
                        Text("dashboard.no_outstanding_issues")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
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
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        }
                    }
                } header: {
                    Text("dashboard.priority_alerts")
                } footer: {
                    if !viewModel.recentIssues.isEmpty {
                        Text("dashboard.priority_alerts_footer")
                    }
                }
                // MARK: - Quick Actions
                Section {
                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        notificationManager.selectedNotificationID = nil // reset if any
                        // Reuse a state for showing sheet
                        showingStartInspection = true
                    }) {
                        Label("dashboard.start_new_inspection", systemImage: "plus.circle.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("dashboard.title")
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
            .onReceive(NotificationCenter.default.publisher(for: AppFormatter.joinInspectionNotification)) { output in
                if let id = output.object as? UUID {
                    Task { await notificationManager.handleJoinRequest(id: id) }
                }
            }
            .navigationDestination(item: $notificationManager.joiningInspection) { inspection in
                InspectionHubView(inspection: inspection)
            }
            .alert("notifications.unable_to_join", isPresented: Binding<Bool>(get: { notificationManager.joinError != nil }, set: { if !$0 { notificationManager.joinError = nil } })) {
                Button("common.ok") { notificationManager.joinError = nil }
            } message: {
                Text(notificationManager.joinError ?? "")
            }
            .sheet(isPresented: $showingStartInspection) {
                StartInspectionSheet()
            }
        }
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return String(localized: "dashboard.greeting.morning") }
        if hour < 17 { return String(localized: "dashboard.greeting.afternoon") }
        return String(localized: "dashboard.greeting.evening")
    }

    private var subtitleText: String {
        if viewModel.properties.isEmpty { return String(localized: "dashboard.subtitle.welcome") }
        if !viewModel.recentIssues.isEmpty {
            let count = viewModel.recentIssues.count
            let format = NSLocalizedString("dashboard.subtitle.attention_count", comment: "")
            return String.localizedStringWithFormat(format, count)
        }
        return String(localized: "dashboard.subtitle.clear")
    }
}

// MARK: - Helper Components

struct DashboardIssueRow: View {
    let issue: DashboardViewModel.DashboardIssue
    
    var body: some View {
        HStack(spacing: 12) {
            if let imgStr = issue.image_url, let url = URL(string: imgStr) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    Color.secondary.opacity(0.1)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: PropertyUI.roomIcon(for: issue.property_rooms.room_type))
                        .foregroundColor(.orange)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(issue.itemName)
                        .font(.headline)
                    Spacer()
                    Text(issue.status.capitalized)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(issue.status == "damaged" ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
                        .foregroundColor(issue.status == "damaged" ? .red : .orange)
                        .clipShape(Capsule())
                }
                
                Text("\(issue.propertyName) • \(issue.roomName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
