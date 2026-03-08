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
        List {
            // MARK: - Property Info
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Area
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.property.name)
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                            
                            Text(viewModel.property.address_line1 ?? "No address provided")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(viewModel.property.property_type.capitalized)
                            .font(.caption2.bold())
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    // Description
                    if let desc = viewModel.property.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About Property")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(.primary.opacity(0.8))
                                .lineSpacing(4)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                    
                    // Stats Bar (Redesigned)
                    HStack(spacing: 12) {
                        statItem(value: "\(viewModel.property.bedrooms_count)", label: "Bedrooms", icon: "bed.double.fill", color: .blue)
                        statItem(value: "\(viewModel.property.bathrooms_count)", label: "Bathrooms", icon: "shower.fill", color: .cyan)
                    }
                }
                .padding(.vertical, 12)
            }

            // MARK: - Rooms
            Section {
                if viewModel.isLoading && viewModel.rooms.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else if viewModel.rooms.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "door.left.hand.closed")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("No rooms yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                } else {
                    ForEach(viewModel.rooms) { room in
                        NavigationLink {
                            RoomInventoryView(room: room)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: PropertyUI.roomIcon(for: room.room_type ?? ""))
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(PropertyUI.roomColor(for: room.room_type ?? "").gradient)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(room.name)
                                        .font(.headline)
                                    
                                    if let desc = room.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(room.room_type?.capitalized ?? "")
                                    .font(.caption2.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.3))
                            }
                            .padding(.vertical, 6)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                // Add delete logic
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                editingRoom = room
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Rooms")
                    Spacer()
                    Text("\(viewModel.rooms.count) Total")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
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
                        viewModel.deleteRooms(at: offsets)
                        HapticManager.shared.notification(type: .success)
                    }
                    roomToDeleteOffsets = nil
                }
            } message: {
                Text("Are you sure you want to delete this room and all its inventory items?")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.property.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.property.name)
                    .font(.headline)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { showingManageTeam = true }) {
                    Image(systemName: "person.3")
                }
            }
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
        }
        .refreshable {
            await viewModel.fetchRooms()
        }
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.headline)
                Text(label)
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemGroupedBackground).opacity(0.5))
        .clipShape(Capsule())
    }
}
