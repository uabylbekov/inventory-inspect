import SwiftUI

struct PropertyDetailView: View {
    @State private var viewModel: PropertyDetailViewModel
    @State private var showingManageTeam = false
    @State private var editingRoom: PropertyRoomModel?
    @State private var showingRoomDeleteAlert = false
    @State private var showingRoomActiveInspectionAlert = false
    @State private var roomActiveInspectionItemCount = 0
    @State private var roomToDeleteOffsets: IndexSet?

    init(property: PropertyModel) {
        _viewModel = State(initialValue: PropertyDetailViewModel(property: property))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Hero Header
                heroSection
                
                // MARK: - Description
                if let desc = viewModel.property.description, !desc.isEmpty {
                    descriptionSection(desc)
                }
                
                // MARK: - Quick Actions
                quickActionsBar
                
                // MARK: - Rooms
                roomsSection
                
                // MARK: - Recent History
                if !viewModel.recentInspections.isEmpty {
                    historySection
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(viewModel.property.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { viewModel.showingAddRoom = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("Add Room")
                                .font(.subheadline.bold())
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
        .sheet(isPresented: $showingManageTeam) {
            ManageTeamSheet(propertyId: viewModel.property.id, isOwner: viewModel.isOwner)
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
    
    // MARK: - Subviews
    
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [.blue.opacity(0.6), .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 180)
                    .overlay(
                        Image(systemName: "map.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.1))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.property.property_type.capitalized)
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary)
                        .clipShape(Capsule())
                    
                    Text(viewModel.property.name)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                .padding(20)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.secondary)
                    Text(viewModel.property.address_line1 ?? "No address recorded")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                HStack(spacing: 12) {
                    statChip(value: "\(viewModel.property.bedrooms_count)", label: "Beds", icon: "bed.double.fill")
                    statChip(value: "\(viewModel.property.bathrooms_count)", label: "Baths", icon: "shower.fill")
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 16)
    }
    
    private func descriptionSection(_ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About Property")
                .font(.headline)
            Text(desc)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(.horizontal)
    }
    
    private var quickActionsBar: some View {
        Button(action: { showingManageTeam = true }) {
            Label("Manage Team", systemImage: "person.2.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal)
    }
    
    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Rooms")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.rooms.count) total")
                    .font(.footnote.bold())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if viewModel.isLoading && viewModel.rooms.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if viewModel.rooms.isEmpty {
                Text("No rooms added yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(viewModel.rooms) { room in
                        NavigationLink {
                            RoomInventoryView(room: room)
                        } label: {
                            RoomCard(room: room)
                                .contextMenu {
                                    Button {
                                        editingRoom = room
                                    } label: {
                                        Label("Edit Room", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        confirmDeleteRoom(room)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(viewModel.recentInspections) { inspection in
                    NavigationLink {
                        if inspection.status == "in_progress" {
                            InspectionHubView(inspection: inspection)
                        } else {
                            InspectionReportView(inspection: inspection)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: AppFormatter.inspectionTypeIcon(for: inspection.inspection_type))
                                .font(.caption.bold())
                                .foregroundColor(AppFormatter.inspectionTypeColor(for: inspection.inspection_type))
                                .frame(width: 28, height: 28)
                                .background(AppFormatter.inspectionTypeColor(for: inspection.inspection_type).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(AppFormatter.formatDate(inspection.started_at))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            StatusBadge(status: inspection.status)
                                .scaleEffect(0.8)

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.3))
                        }
                        .padding()
                    }
                    .buttonStyle(.plain)

                    if inspection.id != viewModel.recentInspections.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal)
        }
    }
    
    private func statChip(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundColor(.accentColor)
            Text("\(value) \(label)")
                .font(.footnote.bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(Capsule())
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

struct RoomCard: View {
    let room: PropertyRoomModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: PropertyUI.roomIcon(for: room.room_type ?? ""))
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(PropertyUI.roomColor(for: room.room_type ?? "").gradient)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(room.room_type?.capitalized ?? "Room")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
