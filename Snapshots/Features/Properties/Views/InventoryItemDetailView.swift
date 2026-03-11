import SwiftUI

struct InventoryItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: InventoryItemDetailViewModel
    @State private var editingItem = false
    @State private var showingDeleteAlert = false
    
    init(item: RoomInventoryItemModel) {
        _viewModel = State(initialValue: InventoryItemDetailViewModel(item: item))
    }
    
    var body: some View {
        List {
            Section {
                LabeledContent("Quantity", value: "\(viewModel.item.expected_qty)")
                LabeledContent("ID", value: viewModel.item.id.uuidString.prefix(8).uppercased())
            }

            if let desc = viewModel.item.description, !desc.isEmpty {
                Section("inventory_item.notes_specs") {
                    Text(desc)
                }
            }

            Section("inventory_item.condition_history") {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.history.isEmpty {
                    ContentUnavailableView(
                        "inventory_item.no_history",
                        systemImage: "clock.badge.questionmark"
                    )
                } else {
                    ForEach(viewModel.history) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.status.capitalized)
                            Text(AppFormatter.formatDate(record.updated_at))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if let notes = record.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("inventory_item.title")
        .applyInlineNavigationTitleIfSupported()
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        editingItem = true
                    } label: {
                        Label("common.edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("common.delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
#else
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button {
                        editingItem = true
                    } label: {
                        Label("common.edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("common.delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
#endif
        }
        .alert("room_inventory.delete_title", isPresented: $showingDeleteAlert) {
            Button("common.cancel", role: .cancel) { }
            Button("common.delete", role: .destructive) {
                Task {
                    HapticManager.shared.impact(style: .medium)
                    let deleted = await viewModel.deleteItem()
                    HapticManager.shared.notification(type: deleted ? .success : .error)
                    if deleted {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("room_inventory.delete_message")
        }
        .sheet(isPresented: $editingItem) {
            EditItemSheet(item: viewModel.item) {
                Task {
                    await viewModel.refreshItem()
                }
            }
        }
        .task {
            await viewModel.fetchHistory()
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
