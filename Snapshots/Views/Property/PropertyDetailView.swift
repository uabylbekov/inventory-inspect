import SwiftUI

struct PropertyDetailView: View {
    @State private var viewModel: PropertyDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingManageTeam = false
    @State private var didLeaveProperty = false
    @State private var editingRoom: PropertyRoomModel?
    @State private var showingRoomDeleteAlert = false
    @State private var showingRoomActiveInspectionAlert = false
    @State private var roomActiveInspectionItemCount = 0
    @State private var roomToDeleteOffsets: IndexSet?
    @State private var showingPaywall = false
    @State private var accessManager = SnapshotsAccessManager.shared

    init(property: PropertyModel) {
        _viewModel = State(initialValue: PropertyDetailViewModel(property: property))
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            // MARK: - Hero Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(PropertyUI.color(for: viewModel.property.property_type).opacity(0.1))
                                .frame(width: 60, height: 60)
                            Image(systemName: PropertyUI.icon(for: viewModel.property.property_type))
                                .font(.title2)
                                .foregroundColor(PropertyUI.color(for: viewModel.property.property_type))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.property.name)
                                .font(.title3.bold())
                            Text(viewModel.property.property_type.capitalized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let address = viewModel.property.address_line1 {
                        Label(address, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 20) {
                        Label("\(viewModel.property.bedrooms_count) Beds", systemImage: "bed.double")
                        Label("\(viewModel.property.bathrooms_count, specifier: "%.1f") Baths", systemImage: "shower")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // MARK: - About
            if let desc = viewModel.property.description, !desc.isEmpty {
                Section("About Property") {
                    Text(desc)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            
            // MARK: - Actions
            Section {
                Button(action: { 
                    if accessManager.isPro {
                        showingManageTeam = true 
                    } else {
                        showingPaywall = true
                    }
                }) {
                    HStack {
                        Label("Manage Team", systemImage: "person.2.fill")
                        Spacer()
                        if accessManager.isPro {
                            PlanBadge()
                        } else {
                            Text("PRO")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            
            // MARK: - Rooms
            Section("Rooms") {
                if viewModel.isLoading && viewModel.rooms.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if viewModel.rooms.isEmpty {
                    Text("No rooms added yet")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(viewModel.rooms) { room in
                        NavigationLink {
                            RoomInventoryView(room: room)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: PropertyUI.roomIcon(for: room.room_type ?? ""))
                                    .foregroundColor(PropertyUI.roomColor(for: room.room_type ?? ""))
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(room.name)
                                        .font(.headline)
                                    Text(room.room_type?.capitalized ?? "Room")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                confirmDeleteRoom(room)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading) {
                            Button { editingRoom = room } label: { Label("Edit", systemImage: "pencil") }
                            .tint(.accentColor)
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                }
            }
            
            // MARK: - Recent Activity
            if !viewModel.recentInspections.isEmpty {
                Section("Recent Activity") {
                    ForEach(viewModel.recentInspections) { inspection in
                        NavigationLink {
                            if inspection.status == "in_progress" {
                                InspectionHubView(inspection: inspection)
                            } else {
                                InspectionReportView(inspection: inspection)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: AppFormatter.inspectionTypeIcon(for: inspection.inspection_type))
                                    .foregroundColor(AppFormatter.inspectionTypeColor(for: inspection.inspection_type))
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                                        .font(.headline)
                                    Text(AppFormatter.formatDate(inspection.started_at))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(inspection.status.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(inspection.status == "in_progress" ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.1))
                                    .foregroundColor(inspection.status == "in_progress" ? .blue : .secondary)
                                    .clipShape(Capsule())
                            }
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.property.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isOwner {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.showingAddRoom = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Add Room")
                        }
                    }
                }
            }
        }
        .alert("Active Inspection Found", isPresented: $showingRoomActiveInspectionAlert) {
            Button("Cancel", role: .cancel) { roomToDeleteOffsets = nil }
            Button("Delete Anyway", role: .destructive) { showingRoomDeleteAlert = true }
        } message: {
            Text("This room has \(roomActiveInspectionItemCount) checked item(s) in an active inspection. Deleting the room will remove that data permanently.")
        }
        .alert("Delete Room?", isPresented: $showingRoomDeleteAlert) {
            Button("Cancel", role: .cancel) {
                roomToDeleteOffsets = nil
            }
            Button("Delete", role: .destructive) {
                if let offsets = roomToDeleteOffsets {
                    HapticManager.shared.impact(style: .medium)
                    Task {
                        await viewModel.deleteRooms(at: offsets)
                        HapticManager.shared.notification(type: .success)
                    }
                }
                roomToDeleteOffsets = nil
            }
        } message: {
            Text("Are you sure you want to delete this room and all its inventory items?")
        }
        .sheet(isPresented: $viewModel.showingAddRoom, onDismiss: {
            Task { await viewModel.fetchRooms() }
        }) {
            AddRoomSheet(propertyId: viewModel.property.id)
        }
        .sheet(isPresented: $showingManageTeam, onDismiss: {
            if didLeaveProperty { dismiss() }
        }) {
            ManageTeamSheet(propertyId: viewModel.property.id, isOwner: viewModel.isOwner, isManager: viewModel.isManager, didLeave: $didLeaveProperty)
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .sheet(item: $editingRoom, onDismiss: {
            Task { await viewModel.fetchRooms() }
        }) { room in
            EditRoomSheet(room: room)
        }
        .task {
            await viewModel.fetchRooms()
            await viewModel.fetchRecentInspections()
        }
        .refreshable {
            await viewModel.fetchRooms()
            await viewModel.fetchRecentInspections()
        }
    }
    
    private func confirmDeleteRoom(_ room: PropertyRoomModel) {
        guard let index = viewModel.rooms.firstIndex(where: { $0.id == room.id }) else { return }
        roomToDeleteOffsets = IndexSet(integer: index)
        Task {
            let count = await viewModel.activeInspectionItemCount(at: roomToDeleteOffsets!)
            if count > 0 {
                roomActiveInspectionItemCount = count
                showingRoomActiveInspectionAlert = true
            } else {
                showingRoomDeleteAlert = true
            }
        }
    }
}
