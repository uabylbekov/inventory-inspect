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
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    HStack(spacing: 20) {
                        Label(
                            String.localizedStringWithFormat(
                                NSLocalizedString("property_detail.beds_count", comment: ""),
                                viewModel.property.bedrooms_count
                            ),
                            systemImage: "bed.double"
                        )
                        Label(
                            String.localizedStringWithFormat(
                                NSLocalizedString("property_detail.baths_count", comment: ""),
                                viewModel.property.bathrooms_count
                            ),
                            systemImage: "shower"
                        )
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            if let desc = viewModel.property.description, !desc.isEmpty {
                Section("property_detail.about") {
                    Text(desc)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Section {
                Button(action: { 
                    if accessManager.isPro(for: viewModel.property) {
                        showingManageTeam = true 
                    } else {
                        showingPaywall = true
                    }
                }) {
                    HStack {
                        Label("property_detail.manage_team", systemImage: "person.2.fill")
                        Spacer()
                        if accessManager.isPro(for: viewModel.property) {
                            Text(accessManager.isDirectSubscriber ? "property_detail.included" : "property_detail.included_here")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                                .foregroundColor(.accentColor)
                        } else {
                            Text("plan.badge.pro")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
            
            Section("property_detail.rooms") {
                if viewModel.isLoading && viewModel.rooms.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if viewModel.rooms.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("property_detail.no_rooms")
                            .foregroundColor(.secondary)
                        if viewModel.isOwner || viewModel.isManager {
                            Button("property_detail.add_room") {
                                viewModel.showingAddRoom = true
                            }
                        }
                    }
                    .padding(.vertical, 4)
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
                                    Text(room.room_type?.capitalized ?? String(localized: "property_detail.room"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                confirmDeleteRoom(room)
                            } label: { Label("common.delete", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading) {
                            Button { editingRoom = room } label: { Label("common.edit", systemImage: "pencil") }
                            .tint(.accentColor)
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                }
            }
            
            if !viewModel.recentInspections.isEmpty {
                Section("property_detail.recent_activity") {
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
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.showingAddRoom = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("property_detail.add_room")
                    }
                }
                .opacity(viewModel.isOwner || viewModel.isManager ? 1 : 0)
                .disabled(!(viewModel.isOwner || viewModel.isManager))
            }
        }
        .alert("property_detail.active_inspection_title", isPresented: $showingRoomActiveInspectionAlert) {
            Button("common.cancel", role: .cancel) { roomToDeleteOffsets = nil }
            Button("property.delete.anyway", role: .destructive) { showingRoomDeleteAlert = true }
        } message: {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("property_detail.active_inspection_message", comment: ""),
                roomActiveInspectionItemCount
            ))
        }
        .alert("property_detail.delete_room_title", isPresented: $showingRoomDeleteAlert) {
            Button("common.cancel", role: .cancel) {
                roomToDeleteOffsets = nil
            }
            Button("common.delete", role: .destructive) {
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
            Text("property_detail.delete_room_message")
        }
        .sheet(isPresented: $viewModel.showingAddRoom) {
            AddRoomSheet(propertyId: viewModel.property.id) {
                Task { await viewModel.fetchRooms() }
            }
        }
        .sheet(isPresented: $showingManageTeam, onDismiss: {
            if didLeaveProperty { dismiss() }
        }) {
            ManageTeamSheet(property: viewModel.property, isOwner: viewModel.isOwner, isManager: viewModel.isManager, didLeave: $didLeaveProperty)
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .sheet(item: $editingRoom) { room in
            EditRoomSheet(room: room) {
                Task { await viewModel.fetchRooms() }
            }
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
