import SwiftUI

struct RoomInventoryView: View {
    let room: PropertyRoomModel
    @State private var viewModel: RoomInventoryViewModel
    
    init(room: PropertyRoomModel) {
        self.room = room
        _viewModel = State(initialValue: RoomInventoryViewModel(room: room))
    }
    
    var body: some View {
        List {
            Section(header: Text("Items")) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.items.isEmpty {
                    Text("No items added yet. Tap + to add one.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                } else {
                    ForEach(viewModel.items) { item in
                        HStack {
                            Text(item.name)
                                .font(.headline)
                                .padding(.vertical, 4)
                            Spacer()
                            Text("\(item.expected_qty)x")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .navigationTitle(room.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.showingAddItem = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Item")
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddItem, onDismiss: {
            Task { await viewModel.fetchItems() }
        }) {
            AddItemSheet(roomId: room.id)
        }
        .task {
            await viewModel.fetchItems()
        }
        .refreshable {
            await viewModel.fetchItems()
        }
    }
}
