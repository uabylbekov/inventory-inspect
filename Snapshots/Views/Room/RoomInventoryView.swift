import SwiftUI

struct RoomInventoryView: View {
    let room: PropertyRoomModel
    @State private var viewModel: RoomInventoryViewModel
    @State private var editingItem: RoomInventoryItemModel?
    @State private var showingItemDeleteAlert = false
    @State private var itemToDelete: RoomInventoryItemModel?
    
    init(room: PropertyRoomModel) {
        self.room = room
        _viewModel = State(initialValue: RoomInventoryViewModel(room: room))
    }
    
    var body: some View {
        List {
            // MARK: - Room Header
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(PropertyUI.roomColor(for: room.room_type ?? "").opacity(0.1))
                                .frame(width: 60, height: 60)
                            Image(systemName: PropertyUI.roomIcon(for: room.room_type ?? ""))
                                .font(.title2)
                                .foregroundColor(PropertyUI.roomColor(for: room.room_type ?? ""))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(room.name)
                                .font(.title3.bold())
                            Text(room.room_type?.capitalized ?? "Room")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 20) {
                        Label("\(viewModel.items.count) Items", systemImage: "cube.box")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // MARK: - Inventory Section
            Section("Inventory") {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "cube.box",
                        description: Text("Add inventory items to track what's in this room.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.items) { item in
                        NavigationLink {
                            InventoryItemDetailView(item: item)
                                .onAppear { HapticManager.shared.impact(style: .light) }
                        } label: {
                            InventoryItemRow(item: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                itemToDelete = item
                                showingItemDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingItem = item
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.accentColor)
                        }
                        .contextMenu {
                            Button {
                                editingItem = item
                            } label: {
                                Label("Edit Item", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                itemToDelete = item
                                showingItemDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.showingAddItem = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Item")
                    }
                }
            }
        }
        .alert("Delete Item?", isPresented: $showingItemDeleteAlert) {
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete, let index = viewModel.items.firstIndex(where: { $0.id == item.id }) {
                    HapticManager.shared.impact(style: .medium)
                    viewModel.deleteItems(at: IndexSet(integer: index))
                    HapticManager.shared.notification(type: .success)
                }
                itemToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this inventory item? This action cannot be undone.")
        }
        .sheet(isPresented: $viewModel.showingAddItem, onDismiss: {
            Task { await viewModel.fetchItems() }
        }) {
            AddItemSheet(roomId: room.id)
        }
        .sheet(item: $editingItem, onDismiss: {
            Task { await viewModel.fetchItems() }
        }) { item in
            EditItemSheet(item: item)
        }
        .task {
            await viewModel.fetchItems()
        }
        .refreshable {
            await viewModel.fetchItems()
        }
    }
}

struct InventoryItemRow: View {
    let item: RoomInventoryItemModel
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "cube.box")
                    .font(.body)
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                if let desc = item.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if item.expected_qty > 1 {
                Text("×\(item.expected_qty)")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
