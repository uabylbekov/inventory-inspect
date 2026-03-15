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
                LabeledContent {
                    Text("\(viewModel.item.expected_qty)")
                } label: {
                    Label("property_sheet.count", systemImage: "number")
                        .symbolRenderingMode(.hierarchical)
                }
                LabeledContent {
                    Text(viewModel.item.id.uuidString.prefix(8).uppercased())
                } label: {
                    Label("common.id", systemImage: "number.square")
                        .symbolRenderingMode(.hierarchical)
                }
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
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(statusTitle(for: record.status))
                                Text(AppFormatter.formatDate(record.updated_at))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let notes = record.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: statusIcon(for: record.status))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(statusColor(for: record.status))
                        }
                        .labelStyle(.titleAndIcon)
                        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
                            dimensions[.leading]
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

private extension InventoryItemDetailView {
    func statusTitle(for status: String) -> String {
        switch status {
        case "missing":
            return String(localized: "inspection_item.status.missing")
        case "damaged":
            return String(localized: "inspection_item.status.damaged")
        case "resolved":
            return String(localized: "inspection_item.status.resolved")
        default:
            return String(localized: "inspection_item.status.present")
        }
    }

    func statusIcon(for status: String) -> String {
        switch status {
        case "missing":
            return "questionmark.circle.fill"
        case "damaged":
            return "exclamationmark.triangle.fill"
        case "resolved":
            return "checkmark.circle.fill"
        default:
            return "checkmark.seal.fill"
        }
    }

    func statusColor(for status: String) -> Color {
        switch status {
        case "missing":
            return .orange
        case "damaged":
            return .red
        case "resolved":
            return .blue
        default:
            return .green
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
