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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Room Hero Header
                roomHeaderSection
                
                // MARK: - Inventory List
                if viewModel.isLoading && viewModel.items.isEmpty {
                    loadingState
                } else if viewModel.items.isEmpty {
                    emptyState
                } else {
                    inventorySection
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    viewModel.showingAddItem = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .symbolRenderingMode(.hierarchical)
                        Text("Add Item")
                    }
                }
            }
        }
        .alert("Delete Item?", isPresented: $showingItemDeleteAlert) {
            Button("Cancel", role: .cancel) { itemToDelete = nil }
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
    
    // MARK: - Subviews
    
    private var roomHeaderSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Gradient with Icon Backdrop
            LinearGradient(
                colors: [PropertyUI.roomColor(for: room.room_type ?? "").opacity(0.8), PropertyUI.roomColor(for: room.room_type ?? "").opacity(1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 140)
            .overlay(
                Image(systemName: PropertyUI.roomIcon(for: room.room_type ?? ""))
                    .font(.system(size: 100))
                    .foregroundColor(.white.opacity(0.15))
                    .offset(x: 40, y: 20),
                alignment: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(room.room_type?.uppercased() ?? "ROOM")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(1)
                
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(viewModel.items.count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Total Items")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(24)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .shadow(color: PropertyUI.roomColor(for: room.room_type ?? "").opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items in \(room.name)")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                ForEach(viewModel.items) { item in
                    NavigationLink {
                        InventoryItemDetailView(item: item)
                            .onAppear { HapticManager.shared.impact(style: .light) }
                    } label: {
                        InventoryItemCard(item: item)
                    }
                    .buttonStyle(.plain)
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
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "plus.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
                .frame(width: 100, height: 100)
                .glassEffect(in: Circle())
            
            VStack(spacing: 8) {
                Text("Start Your Inventory")
                    .font(.title3.bold())
                Text("Keep track of every furniture, appliance, or valuable in this room.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: { viewModel.showingAddItem = true }) {
                Text("Add First Item")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(minHeight: 400)
    }
    
    private var loadingState: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
                .padding()
            Text("Fetching Inventory...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

struct InventoryItemCard: View {
    let item: RoomInventoryItemModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Placeholder/Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "cube.box")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let desc = item.description, !desc.isEmpty {
                    Text(desc)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if item.expected_qty > 1 {
                Text("QTY \(item.expected_qty)")
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.secondary)
                    .clipShape(Capsule())
            }
            
            Image(systemName: "chevron.right")
                .font(.caption2.bold())
                .foregroundColor(.secondary.opacity(0.3))
        }
        .padding(14)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
