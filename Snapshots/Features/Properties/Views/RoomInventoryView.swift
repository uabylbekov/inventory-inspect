import SwiftUI

struct RoomInventoryView: View {
    @Environment(\.dismiss) private var dismiss
    let room: PropertyRoomModel
    @State private var viewModel: RoomInventoryViewModel
    @State private var editingItem: RoomInventoryItemModel?
    @State private var editingRoom = false
    @State private var showingItemDeleteAlert = false
    @State private var showingRoomDeleteAlert = false
    @State private var showingRoomActiveInspectionAlert = false
    @State private var itemToDelete: RoomInventoryItemModel?
    @State private var roomActiveInspectionItemCount = 0
    
    init(room: PropertyRoomModel) {
        self.room = room
        _viewModel = State(initialValue: RoomInventoryViewModel(room: room))
    }
    
    var body: some View {
        List {
            Section {
                roomHeader
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }

            Section("room_inventory.inventory") {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "room_inventory.empty_title",
                        systemImage: "cube.box",
                        description: Text("room_inventory.empty_message")
                    )
                } else {
                    ForEach(viewModel.items) { item in
                        NavigationLink {
                            InventoryItemDetailView(item: item)
                                .onAppear { HapticManager.shared.impact(style: .light) }
                        } label: {
                            InventoryItemRow(item: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if viewModel.canManageInventory {
                                Button(role: .destructive) {
                                    itemToDelete = item
                                    showingItemDeleteAlert = true
                                } label: {
                                    Label("common.delete", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if viewModel.canManageInventory {
                                Button {
                                    editingItem = item
                                } label: {
                                    Label("common.edit", systemImage: "pencil")
                                }
                                .tint(.accentColor)
                            }
                        }
                        .contextMenu {
                            if viewModel.canManageInventory {
                                Button {
                                    editingItem = item
                                } label: {
                                    Label("room_inventory.edit_item", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    itemToDelete = item
                                    showingItemDeleteAlert = true
                                } label: {
                                    Label("common.delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.fetchItems(showLoadingState: false)
        }
        .navigationTitle(room.name)
        .applyInlineNavigationTitleIfSupported()
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                if viewModel.canManageInventory {
                    Menu {
                        Button {
                            editingRoom = true
                        } label: {
                            Label("common.edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            confirmDeleteRoom()
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
#else
            ToolbarItem(placement: .automatic) {
                if viewModel.canManageInventory {
                    Menu {
                        Button {
                            editingRoom = true
                        } label: {
                            Label("common.edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            confirmDeleteRoom()
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
#endif
            ToolbarItem(placement: .primaryAction) {
                if viewModel.canManageInventory {
                    Button(action: { viewModel.showingAddItem = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("room_inventory.add_item")
                        }
                    }
                }
            }
        }
        .alert("property_detail.active_inspection_title", isPresented: $showingRoomActiveInspectionAlert) {
            Button("common.cancel", role: .cancel) { }
            Button("property.delete.anyway", role: .destructive) {
                showingRoomDeleteAlert = true
            }
        } message: {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("property_detail.active_inspection_message", comment: ""),
                roomActiveInspectionItemCount
            ))
        }
        .alert("property_detail.delete_room_title", isPresented: $showingRoomDeleteAlert) {
            Button("common.cancel", role: .cancel) { }
            Button("common.delete", role: .destructive) {
                Task {
                    HapticManager.shared.impact(style: .medium)
                    let deleted = await viewModel.deleteRoom()
                    HapticManager.shared.notification(type: deleted ? .success : .error)
                    if deleted {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("property_detail.delete_room_message")
        }
        .alert("room_inventory.delete_title", isPresented: $showingItemDeleteAlert) {
            Button("common.cancel", role: .cancel) {
                itemToDelete = nil
            }
            Button("common.delete", role: .destructive) {
                if let item = itemToDelete {
                    Task {
                        HapticManager.shared.impact(style: .medium)
                        let deleted = await viewModel.deleteItem(item)
                        HapticManager.shared.notification(type: deleted ? .success : .error)
                    }
                }
                itemToDelete = nil
            }
        } message: {
            Text("room_inventory.delete_message")
        }
        .sheet(isPresented: $viewModel.showingAddItem) {
            AddItemSheet(roomId: room.id) {
                Task { await viewModel.fetchItems(showLoadingState: false) }
            }
        }
        .sheet(isPresented: $editingRoom) {
            EditRoomSheet(room: room) {
                Task { await viewModel.fetchItems(showLoadingState: false) }
            }
        }
        .sheet(item: $editingItem) { item in
            EditItemSheet(item: item) {
                Task { await viewModel.fetchItems(showLoadingState: false) }
            }
        }
        .task {
            async let itemsTask: () = viewModel.fetchItems()
            async let accessTask: () = viewModel.refreshAccess()
            _ = await (itemsTask, accessTask)
        }
    }

    private func confirmDeleteRoom() {
        Task {
            let count = await viewModel.activeInspectionItemCount()
            if count > 0 {
                roomActiveInspectionItemCount = count
                showingRoomActiveInspectionAlert = true
            } else {
                showingRoomDeleteAlert = true
            }
        }
    }

    private var roomHeader: some View {
        Group {
            LabeledContent("room_sheet.type", value: room.room_type?.capitalized ?? String(localized: "property_detail.room"))
            LabeledContent("Items", value: "\(viewModel.items.count)")
        }
    }
}

private extension View {
    @ViewBuilder
    func applyInlineNavigationTitleIfSupported() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }
}

struct InventoryItemRow: View {
    let item: RoomInventoryItemModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .lineLimit(1)

            if let desc = item.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if item.expected_qty > 1 {
                Text("×\(item.expected_qty)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
