import SwiftUI

struct InspectionHubView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: InspectionHubViewModel
    @State private var showCancelAlert = false
    @State private var cancelReason = ""
    
    init(inspection: InspectionModel) {
        _viewModel = State(initialValue: InspectionHubViewModel(inspection: inspection))
    }
    
    private var totalItems: Int {
        viewModel.allInventoryItems.count
    }
    
    private var checkedItems: Int {
        viewModel.inspectionItems.count
    }
    
    var body: some View {
        List {
            if viewModel.isLoading && viewModel.rooms.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
            } else if viewModel.rooms.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Rooms",
                        systemImage: "door.left.hand.closed",
                        description: Text("This property has no rooms. Add rooms to the property first.")
                    )
                }
            } else {
                // MARK: - Progress Tracker
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "list.clipboard.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.accentColor.gradient)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("In-Progress Check")
                                .font(.headline)
                            Text("\(checkedItems) of \(totalItems) Checked")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .stroke(Color.accentColor.opacity(0.1), lineWidth: 4)
                            Circle()
                                .trim(from: 0, to: totalItems > 0 ? Double(checkedItems) / Double(totalItems) : 0)
                                .stroke(checkedItems == totalItems && totalItems > 0 ? Color.green : Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(totalItems > 0 ? Int(Double(checkedItems) / Double(totalItems) * 100) : 0)%")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .frame(width: 36, height: 36)
                    }
                    .padding(.vertical, 6)
                }
                
                // MARK: - Rooms & Items (Settings-style)
                ForEach(viewModel.rooms) { room in
                    let roomItems = viewModel.allInventoryItems.filter { $0.room_id == room.id }
                    
                    if !roomItems.isEmpty {
                        Section {
                            ForEach(roomItems) { item in
                                let record = viewModel.inspectionItems.first { $0.inventory_item_id == item.id }
                                NavigationLink {
                                    InspectionItemDetailView(
                                        item: item,
                                        inspection: viewModel.inspection,
                                        room: room,
                                        initialRecord: record
                                    )
                                } label: {
                                    ItemRow(item: item, record: record)
                                }
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            }
                        } header: {
                            HStack {
                                Text(room.name)
                                Spacer()
                                let roomChecked = roomItems.filter { item in
                                    viewModel.inspectionItems.contains { $0.inventory_item_id == item.id }
                                }.count
                                Text("\(roomChecked)/\(roomItems.count)")
                                    .font(.caption2.bold())
                                    .foregroundColor(roomChecked == roomItems.count ? .green : .secondary)
                            }
                        }
                    }
                }
                
                // MARK: - Action Buttons
                if viewModel.inspection.status == "in_progress" {
                    Section {
                        HStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    HapticManager.shared.impact(style: .medium)
                                    let success = await viewModel.completeInspection()
                                    if success {
                                        HapticManager.shared.notification(type: .success)
                                        dismiss()
                                    } else {
                                        HapticManager.shared.notification(type: .error)
                                    }
                                }
                            }) {
                                HStack {
                                    if viewModel.isCompleting {
                                        ProgressView().tint(.white)
                                            .padding(.trailing, 4)
                                    }
                                    Label("Complete", systemImage: "checkmark.seal.fill")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.large)
                            .disabled(!viewModel.allRoomsComplete || viewModel.isCompleting)
                            
                            Button(role: .destructive) {
                                cancelReason = ""
                                showCancelAlert = true
                            } label: {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 12, trailing: 0))
                    } footer: {
                        if !viewModel.allRoomsComplete {
                            Text("Finish all rooms to complete.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            
            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: viewModel.isLoading)
        .navigationTitle("Inspection")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cancel Inspection?", isPresented: $showCancelAlert) {
            TextField("Reason (optional)", text: $cancelReason)
            Button("Keep Going", role: .cancel) {}
            Button("Cancel Inspection", role: .destructive) {
                Task {
                    let success = await viewModel.cancelInspection(reason: cancelReason)
                    if success {
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    } else {
                        HapticManager.shared.notification(type: .error)
                    }
                }
            }
        } message: {
            Text("This inspection will be marked as cancelled. You can't undo this action.")
        }
        .task {
            await viewModel.fetchData()
            await viewModel.setupRealtime()
        }
        .refreshable {
            await viewModel.fetchData()
        }
    }
}

// MARK: - Item Row

private struct ItemRow: View {
    let item: RoomInventoryItemModel
    let record: InspectionItemModel?
    
    private var status: String { record?.status ?? "pending" }
    
    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                    
                    if item.expected_qty > 1 {
                        Text("Qty: \(item.expected_qty)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } icon: {
                Image(systemName: StatusUI.icon(for: status))
                    .foregroundColor(StatusUI.color(for: status))
            }
            
            Spacer()
            
            if status != "pending" {
                StatusBadge(status: status)
            } else {
                Text("Pending")
                    .foregroundColor(.secondary)
            }
        }
    }
}
