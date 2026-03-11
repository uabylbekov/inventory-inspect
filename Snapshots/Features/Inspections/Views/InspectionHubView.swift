import SwiftUI

struct InspectionHubView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: InspectionHubViewModel
    @State private var showCancelAlert = false
    @State private var cancelReason = ""
    @State private var showCompleteAlert = false
    @State private var showDeleteAlert = false
    
    init(inspection: InspectionModel) {
        _viewModel = State(initialValue: InspectionHubViewModel(inspection: inspection))
    }
    
    private var totalItems: Int {
        viewModel.allInventoryItems.count
    }
    
    private var checkedItems: Int {
        viewModel.inspectionItems.count
    }
    
    private var progressValue: Double {
        totalItems > 0 ? Double(checkedItems) / Double(totalItems) : 0
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                LabeledContent("Type", value: AppFormatter.formatInspectionType(viewModel.inspection.inspection_type))
                LabeledContent("Progress", value: "\(checkedItems)/\(totalItems)")
            }

            if viewModel.isLoading && viewModel.rooms.isEmpty {
                Section {
                    ProgressView("inspection_hub.loading")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else if viewModel.rooms.isEmpty {
                EmptyView()
            } else {
                ForEach(sortedRooms) { room in
                    let roomItems = viewModel.allInventoryItems.filter { $0.room_id == room.id }
                    let progress = viewModel.roomProgress(for: room.id)
                    
                    if !roomItems.isEmpty {
                        Section {
                            ForEach(roomItems) { item in
                                let record = viewModel.inspectionRecord(for: item.id)
                                NavigationLink {
                                    InspectionItemDetailView(
                                        item: item,
                                        inspection: viewModel.inspection,
                                        room: room,
                                        property: viewModel.property,
                                        initialRecord: record
                                    )
                                } label: {
                                    TacticalItemRow(item: item, record: record)
                                }
                            }
                        } header: {
                            HStack {
                                Text(room.name)
                                Spacer()
                                if let progress = progress, progress.isComplete {
                                    Text("Done")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(progress?.progressString ?? String(localized: "common.empty"))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if viewModel.inspection.status == "in_progress" && viewModel.allRoomsComplete {
                Section {
                    Button(action: {
                        showCompleteAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("inspection_hub.complete")
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.accentColor)
                }
            }
        }
        .navigationTitle(viewModel.property?.name ?? String(localized: "inspection_hub.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.inspection.status == "in_progress" {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showCancelAlert = true
                        } label: {
                            Label("inspection_hub.cancel", systemImage: "xmark.circle")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("inspection_hub.delete_permanently", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("inspection_hub.cancel_title", isPresented: $showCancelAlert) {
            TextField("inspection_hub.reason_optional", text: $cancelReason)
            Button("inspection_hub.keep_going", role: .cancel) {
                cancelReason = ""
            }
            Button("inspection_hub.cancel", role: .destructive) {
                Task {
                    let success = await viewModel.cancelInspection(reason: cancelReason)
                    if success {
                        HapticManager.shared.notification(type: .success)
                        cancelReason = ""
                        dismiss()
                    }
                }
            }
        } message: {
            Text("inspection_hub.cancel_message")
        }
        .alert("inspection_hub.delete_title", isPresented: $showDeleteAlert) {
            Button("common.cancel", role: .cancel) { }
            Button("inspection_hub.delete_forever", role: .destructive) {
                Task {
                    let success = await viewModel.deleteInspection()
                    if success {
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    }
                }
            }
        } message: {
            Text("inspection_hub.delete_message")
        }
        .task {
            await viewModel.fetchData()
            await viewModel.setupRealtime()
        }
        .onDisappear {
            viewModel.unsubscribe()
        }
        .alert("inspection_hub.complete_title", isPresented: $showCompleteAlert) {
            Button("inspection_hub.not_yet", role: .cancel) {}
            Button("inspection_hub.complete", action: {
                Task {
                    HapticManager.shared.impact(style: .medium)
                    let success = await viewModel.completeInspection()
                    if success {
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    }
                }
            })
        } message: {
            Text("inspection_hub.complete_message")
        }
    }

    private var sortedRooms: [PropertyRoomModel] {
        viewModel.rooms.sorted { lhs, rhs in
            let lhsComplete = viewModel.roomProgress(for: lhs.id)?.isComplete ?? false
            let rhsComplete = viewModel.roomProgress(for: rhs.id)?.isComplete ?? false
            if lhsComplete == rhsComplete {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return !lhsComplete && rhsComplete
        }
    }
}

struct TacticalItemRow: View {
    let item: RoomInventoryItemModel
    let record: InspectionItemModel?
    
    var status: String { record?.status ?? "pending" }
    
    private var statusColor: Color {
        switch status {
        case "present":
            return .green
        case "missing":
            return .orange
        case "damaged":
            return .red
        case "resolved":
            return .blue
        default:
            return .secondary
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)

                HStack(spacing: 8) {
                    Text(status.capitalized)
                        .font(.caption)
                        .foregroundColor(statusColor)

                    if item.expected_qty > 1 {
                        Text(String.localizedStringWithFormat(
                            NSLocalizedString("inspection_hub.qty", comment: ""),
                            item.expected_qty
                        ))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    if let notes = record?.notes, !notes.isEmpty {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
    }
}
