import SwiftUI

struct PropertyDetailView: View {
    @State private var viewModel: PropertyDetailViewModel
    @State private var showingManageTeam = false
    
    init(property: PropertyModel) {
        _viewModel = State(initialValue: PropertyDetailViewModel(property: property))
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.property.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let address = viewModel.property.address_line1, !address.isEmpty {
                        Text(address)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("🛏️ \(viewModel.property.bedrooms_count) Beds")
                        Spacer()
                        Text("🚿 \(viewModel.property.bathrooms_count, specifier: "%.1f") Baths")
                        Spacer()
                        Text(viewModel.property.property_type)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(8)
                    }
                    .font(.subheadline)
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Rooms")) {
                if viewModel.isLoading && viewModel.rooms.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.rooms.isEmpty {
                    Text("No rooms added yet. Tap + to add one.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                } else {
                    ForEach(viewModel.rooms) { room in
                        NavigationLink {
                            RoomInventoryView(room: room)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(room.name)
                                    .font(.headline)
                                if let type = room.room_type {
                                    Text(type)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Property Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    if viewModel.isOwner {
                        Button(action: { showingManageTeam = true }) {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                    
                    // Cleaners cannot add rooms, only owners and managers
                    if viewModel.isOwner {
                        Button(action: { viewModel.showingAddRoom = true }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Room")
                            }
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
            ManageTeamSheet(propertyId: viewModel.property.id)
        }
        .task {
            await viewModel.fetchRooms()
        }
        .refreshable {
            await viewModel.fetchRooms()
        }
    }
}
