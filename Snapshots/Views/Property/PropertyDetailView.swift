import SwiftUI

struct PropertyDetailView: View {
    @State private var viewModel: PropertyDetailViewModel
    @State private var showingManageTeam = false
    @State private var editingRoom: PropertyRoomModel?
    @State private var showingRoomDeleteAlert = false
    @State private var showingRoomActiveInspectionAlert = false
    @State private var roomActiveInspectionItemCount = 0
    @State private var roomToDeleteOffsets: IndexSet?
    @State private var showingStartInspection = false
    
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
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(viewModel.property.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { showingManageTeam = true }) {
                        Label("Manage Team", systemImage: "person.3")
                    }
                    if viewModel.isOwner {
                        Button(action: { viewModel.showingAddRoom = true }) {
                            Label("Add Room", systemImage: "plus")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
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
            Button("Cancel", role: .cancel) { roomToDeleteOffsets = nil }
            Button("Delete", role: .destructive) {
                if let offsets = roomToDeleteOffsets {
                    HapticManager.shared.impact(style: .medium)
                    viewModel.deleteRooms(at: offsets)
                    HapticManager.shared.notification(type: .success)
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
        .sheet(isPresented: $showingStartInspection) {
            StartInspectionSheet()
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
                        .background(.ultraThinMaterial)
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
                        .font(.subheadline)
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
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(.horizontal)
    }
    
    private var quickActionsBar: some View {
        HStack(spacing: 16) {
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                showingStartInspection = true
            }) {
                Label("Start Inspection", systemImage: "plus.viewfinder")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.gradient)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            
            Button(action: { showingManageTeam = true }) {
                Image(systemName: "person.2.fill")
                    .font(.headline)
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(.horizontal)
    }
    
    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Rooms")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.rooms.count) total")
                    .font(.caption.bold())
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
                            Circle()
                                .fill(inspection.status == "completed" ? Color.green : Color.blue)
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                Text(AppFormatter.formatDate(inspection.started_at))
                                    .font(.caption2)
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
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                    }
                    
                    if inspection.id != viewModel.recentInspections.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal)
        }
    }
    
    private func statChip(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)
            Text("\(value) \(label)")
                .font(.caption.bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(Capsule())
    }
    
    private func confirmDeleteRoom(_ room: PropertyRoomModel) {
        roomToDeleteOffsets = IndexSet(integer: viewModel.rooms.firstIndex(where: { $0.id == room.id }) ?? 0)
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
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(room.room_type?.capitalized ?? "Room")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
