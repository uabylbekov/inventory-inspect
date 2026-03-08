import SwiftUI

struct RoomInventoryView: View {
    let room: PropertyRoomModel
    @State private var viewModel: RoomInventoryViewModel
    @State private var editingItem: RoomInventoryItemModel?
    @State private var showingItemDeleteAlert = false
    @State private var itemToDeleteOffsets: IndexSet?
    
    init(room: PropertyRoomModel) {
        self.room = room
        _viewModel = State(initialValue: RoomInventoryViewModel(room: room))
    }
    
    var body: some View {
        List {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
            } else if viewModel.items.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("No items yet")
                            .font(.headline)
                        Text("Tap + to add inventory items to this room.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                }
            } else {
                Section {
                    ForEach(viewModel.items) { item in
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .foregroundColor(.primary)
                                    
                                    if let desc = item.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } icon: {
                                Image(systemName: "cube.box.fill")
                                    .foregroundColor(.accentColor)
                            }
                            
                            Spacer()
                            
                            if item.expected_qty > 1 {
                                Text("×\(item.expected_qty)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                                    .clipShape(Capsule())
                            }
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingItem = item
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete { offsets in
                        itemToDeleteOffsets = offsets
                        showingItemDeleteAlert = true
                    }
                } header: {
                    Text("\(viewModel.items.count) Items")
                }
                .alert("Delete Item?", isPresented: $showingItemDeleteAlert) {
                    Button("Cancel", role: .cancel) {
                        itemToDeleteOffsets = nil
                    }
                    Button("Delete", role: .destructive) {
                        if let offsets = itemToDeleteOffsets {
                            HapticManager.shared.impact(style: .medium)
                            viewModel.deleteItems(at: offsets)
                            HapticManager.shared.notification(type: .success)
                        }
                        itemToDeleteOffsets = nil
                    }
                } message: {
                    Text("Are you sure you want to delete this specific inventory item?")
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: viewModel.isLoading)
        .navigationTitle(room.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.showingAddItem = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Inventory")
                    }
                }
            }
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
