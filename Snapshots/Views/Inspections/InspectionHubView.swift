import SwiftUI

struct InspectionHubView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: InspectionHubViewModel
    @State private var showCancelAlert = false
    @State private var cancelReason = ""
    @State private var showCompleteAlert = false
    
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
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // MARK: - Tactical Progress Header
                    tacticalHeader
                    
                    // MARK: - Rooms Navigation
                    if viewModel.isLoading && viewModel.rooms.isEmpty {
                        loadingState
                    } else if viewModel.rooms.isEmpty {
                        emptyState
                    } else {
                        roomsGrid
                    }
                    
                    // Add padding for the sticky bottom bar
                    Spacer().frame(height: 100)
                }
                .padding(.top, 16)
            }
            .refreshable {
                await viewModel.fetchData()
            }
            
            // MARK: - Sticky Bottom Action Bar
            if viewModel.inspection.status == "in_progress" {
                bottomActionBar
            }
        }
        .navigationTitle("Inspection Hub")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.inspection.status == "in_progress" {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive, action: { showCancelAlert = true }) {
                        Label("Cancel Inspection", systemImage: "xmark")
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
        .alert("Complete Inspection?", isPresented: $showCompleteAlert) {
            Button("Not Yet", role: .cancel) {}
            Button("Complete") {
                Task {
                    HapticManager.shared.impact(style: .medium)
                    let success = await viewModel.completeInspection()
                    if success {
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This will finalize the inspection and generate a report. No further changes can be made after completing.")
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.inspectionItems.count)
    }
    
    // MARK: - Subviews
    
    private var tacticalHeader: some View {
        VStack(spacing: 20) {
            HStack(spacing: 24) {
                // Progress Gauge
                ZStack {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.1), lineWidth: 10)
                        .frame(width: 90, height: 90)
                    
                    Circle()
                        .trim(from: 0, to: progressValue)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [Color.accentColor.opacity(0.6), Color.accentColor]),
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 90, height: 90)
                    
                    VStack(spacing: -2) {
                        Text("\(Int(progressValue * 100))%")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                        Text("DONE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .shadow(color: Color.accentColor.opacity(0.15), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppFormatter.formatInspectionType(viewModel.inspection.inspection_type))
                        .font(.footnote.bold())
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Text("Inventory Check")
                        .font(.title3.bold())
                    
                    Text("\(checkedItems) of \(totalItems) items checked")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(24)
            .glassEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal)
        }
    }
    
    private var roomsGrid: some View {
        let incompleteFirst = viewModel.rooms.sorted { a, b in
            let aItems = viewModel.allInventoryItems.filter { $0.room_id == a.id }
            let aComplete = !aItems.isEmpty && aItems.allSatisfy { item in
                viewModel.inspectionItems.contains { $0.inventory_item_id == item.id }
            }
            let bItems = viewModel.allInventoryItems.filter { $0.room_id == b.id }
            let bComplete = !bItems.isEmpty && bItems.allSatisfy { item in
                viewModel.inspectionItems.contains { $0.inventory_item_id == item.id }
            }
            return !aComplete && bComplete
        }
        return VStack(alignment: .leading, spacing: 16) {
            Text("Room Walkthrough")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 20) {
                ForEach(incompleteFirst) { room in
                    let roomItems = viewModel.allInventoryItems.filter { $0.room_id == room.id }
                    if !roomItems.isEmpty {
                        let roomCheckedCount = roomItems.filter { item in
                            viewModel.inspectionItems.contains { $0.inventory_item_id == item.id }
                        }.count

                        RoomWalkthroughCard(
                            room: room,
                            checkedCount: roomCheckedCount,
                            totalCount: roomItems.count,
                            items: roomItems,
                            viewModel: viewModel
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var bottomActionBar: some View {
        Button(action: {
            showCompleteAlert = true
        }) {
            HStack(spacing: 12) {
                if viewModel.isCompleting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.headline)
                }
                Text("Complete Inspection")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(viewModel.allRoomsComplete ? Color.green.gradient : Color.accentColor.gradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: (viewModel.allRoomsComplete ? Color.green : Color.accentColor).opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .disabled(!viewModel.allRoomsComplete || viewModel.isCompleting)
        .opacity(viewModel.allRoomsComplete ? 1.0 : 0.6)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 34)
        .background(.ultraThinMaterial)
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            "Ready for Duty",
            systemImage: "clipboard.fill",
            description: Text("No items available to inspect. This is usually due to a property having no inventory assigned.")
        )
        .padding(.top, 60)
    }
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Priming Hub...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Tactical Components

struct RoomWalkthroughCard: View {
    let room: PropertyRoomModel
    let checkedCount: Int
    let totalCount: Int
    let items: [RoomInventoryItemModel]
    let viewModel: InspectionHubViewModel
    
    var isComplete: Bool {
        checkedCount == totalCount
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Room Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: PropertyUI.roomIcon(for: room.room_type ?? ""))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(PropertyUI.roomColor(for: room.room_type ?? "").gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(room.name)
                            .font(.headline)
                        Text("\(checkedCount)/\(totalCount) Done")
                            .font(.caption)
                            .foregroundColor(isComplete ? .green : .secondary)
                    }
                }
                
                Spacer()
                
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    Text("\(Int(Double(checkedCount) / Double(totalCount) * 100))%")
                        .font(.caption.bold())
                        .monospacedDigit()
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            
            // Item List
            VStack(spacing: 0) {
                ForEach(items) { item in
                    let record = viewModel.inspectionItems.first { $0.inventory_item_id == item.id }
                    
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
                    .buttonStyle(.plain)
                    
                    if item.id != items.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct TacticalItemRow: View {
    let item: RoomInventoryItemModel
    let record: InspectionItemModel?
    
    var status: String { record?.status ?? "pending" }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(StatusUI.color(for: status).opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: StatusUI.icon(for: status))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(StatusUI.color(for: status))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if item.expected_qty > 1 {
                    Text("Expected Qty: \(item.expected_qty)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if status != "pending" {
                StatusBadge(status: status)
                    .scaleEffect(0.85)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
