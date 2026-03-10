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
        Group {
            if !viewModel.isLoading && viewModel.items.isEmpty {
                ScrollView {
                    VStack(spacing: 24) {
                        roomHeader
                            .padding(.horizontal)

                        ContentUnavailableView(
                            "room_inventory.empty_title",
                            systemImage: "cube.box",
                            description: Text("room_inventory.empty_message")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    await viewModel.fetchItems(showLoadingState: false)
                }
            } else {
                List {
                    Section {
                        roomHeader
                    }
                    
                    Section("room_inventory.inventory") {
                        if viewModel.isLoading && viewModel.items.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
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
                                        Label("common.delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        editingItem = item
                                    } label: {
                                        Label("common.edit", systemImage: "pencil")
                                    }
                                    .tint(.accentColor)
                                }
                                .contextMenu {
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
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.fetchItems(showLoadingState: false)
                }
            }
        }
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.showingAddItem = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("room_inventory.add_item")
                    }
                }
            }
        }
        .alert("room_inventory.delete_title", isPresented: $showingItemDeleteAlert) {
            Button("common.cancel", role: .cancel) {
                itemToDelete = nil
            }
            Button("common.delete", role: .destructive) {
                if let item = itemToDelete, let index = viewModel.items.firstIndex(where: { $0.id == item.id }) {
                    HapticManager.shared.impact(style: .medium)
                    viewModel.deleteItems(at: IndexSet(integer: index))
                    HapticManager.shared.notification(type: .success)
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
        .sheet(item: $editingItem) { item in
            EditItemSheet(item: item) {
                Task { await viewModel.fetchItems(showLoadingState: false) }
            }
        }
        .task {
            await viewModel.fetchItems()
        }
    }

    private var roomHeader: some View {
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
                    Text(room.room_type?.capitalized ?? String(localized: "property_detail.room"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 20) {
                Label(
                    String.localizedStringWithFormat(
                        NSLocalizedString("room_inventory.items_count", comment: ""),
                        viewModel.items.count
                    ),
                    systemImage: "cube.box"
                )
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
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
