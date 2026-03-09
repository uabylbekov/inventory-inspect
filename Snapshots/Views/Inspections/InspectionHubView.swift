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
            // MARK: - Progress Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.property?.name ?? "Loading...")
                                .font(.headline)
                            Text(AppFormatter.formatInspectionType(viewModel.inspection.inspection_type))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(lineWidth: 4)
                                .opacity(0.1)
                                .foregroundColor(.accentColor)
                                .frame(width: 44, height: 44)
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(min(self.progressValue, 1.0)))
                                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                                .foregroundColor(.accentColor)
                                .rotationEffect(Angle(degrees: 270.0))
                                .frame(width: 44, height: 44)
                            
                            Text("\(Int(progressValue * 100))%")
                                .font(.caption2.bold())
                        }
                    }
                    
                    ProgressView(value: progressValue)
                        .tint(.accentColor)
                    
                    Text("\(checkedItems) of \(totalItems) items checked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // MARK: - Room Walkthrough
            if viewModel.isLoading && viewModel.rooms.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading Hub...")
                        Spacer()
                    }
                }
            } else if viewModel.rooms.isEmpty {
                EmptyView()
            } else {
                ForEach(viewModel.rooms) { room in
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
                                        initialRecord: record
                                    )
                                } label: {
                                    TacticalItemRow(item: item, record: record)
                                }
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            }
                        } header: {
                            HStack {
                                Label(room.name, systemImage: PropertyUI.roomIcon(for: room.room_type ?? ""))
                                Spacer()
                                if let progress = progress, progress.isComplete {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Text(progress?.progressString ?? "")
                                }
                            }
                        }
                    }
                }
            }
            
            // MARK: - Actions
            if viewModel.inspection.status == "in_progress" {
                Section {
                    Button(action: {
                        if viewModel.allRoomsComplete {
                            showCompleteAlert = true
                        }
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.allRoomsComplete {
                                Label("Complete Inspection", systemImage: "checkmark.seal.fill")
                                    .fontWeight(.bold)
                            } else {
                                let remaining = viewModel.roomProgressList.filter { !$0.isComplete }.count
                                Text("\(remaining) rooms remaining to check")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.allRoomsComplete)
                    .listRowBackground(viewModel.allRoomsComplete ? Color.accentColor : Color.secondary.opacity(0.1))
                    .foregroundColor(viewModel.allRoomsComplete ? .white : .secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Inspection Hub")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.inspection.status == "in_progress" {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showCancelAlert = true
                        } label: {
                            Label("Cancel Inspection", systemImage: "xmark.circle")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete Permanently", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Cancel Inspection?", isPresented: $showCancelAlert) {
            TextField("Reason (optional)", text: $cancelReason)
            Button("Keep Going", role: .cancel) {
                cancelReason = ""
            }
            Button("Cancel Inspection", role: .destructive) {
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
            Text("This inspection will be marked as cancelled. You can't undo this action.")
        }
        .alert("Delete Permanently?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Forever", role: .destructive) {
                Task {
                    let success = await viewModel.deleteInspection()
                    if success {
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This will completely remove this inspection and all its records from the database. This cannot be undone.")
        }
        .task {
            await viewModel.fetchData()
            await viewModel.setupRealtime()
        }
        .onDisappear {
            viewModel.unsubscribe()
        }
        .alert("Complete Inspection?", isPresented: $showCompleteAlert) {
            Button("Not Yet", role: .cancel) {}
            Button("Complete", action: {
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
            Text("This will finalize the inspection and generate a report. No further changes can be made after completing.")
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.inspectionItems.count)
    }
}

struct TacticalItemRow: View {
    let item: RoomInventoryItemModel
    let record: InspectionItemModel?
    
    var status: String { record?.status ?? "pending" }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(StatusUI.color(for: status).opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: StatusUI.icon(for: status))
                    .font(.caption)
                    .foregroundColor(StatusUI.color(for: status))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                
                if item.expected_qty > 1 {
                    Text("Qty: \(item.expected_qty)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if status != "pending" {
                Text(status.capitalized)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(StatusUI.color(for: status).opacity(0.1))
                    .foregroundColor(StatusUI.color(for: status))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}
