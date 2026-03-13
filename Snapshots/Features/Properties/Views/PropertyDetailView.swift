import SwiftUI

struct PropertyDetailView: View {
    @State private var viewModel: PropertyDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingManageTeam = false
    @State private var didLeaveProperty = false
    @State private var editingRoom: PropertyRoomModel?
    @State private var editingProperty = false
    @State private var showingRoomDeleteAlert = false
    @State private var showingRoomActiveInspectionAlert = false
    @State private var showingPropertyDeleteAlert = false
    @State private var showingPropertyActiveInspectionAlert = false
    @State private var roomActiveInspectionItemCount = 0
    @State private var propertyActiveInspectionCount = 0
    @State private var roomToDeleteOffsets: IndexSet?
    @State private var showingPaywall = false

    init(property: PropertyModel) {
        _viewModel = State(initialValue: PropertyDetailViewModel(property: property))
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                LabeledContent {
                    Text(viewModel.property.property_type.capitalized)
                } label: {
                    Label {
                        Text("property_sheet.property_type")
                    } icon: {
                        Image(systemName: PropertyUI.icon(for: viewModel.property.property_type))
                            .foregroundStyle(PropertyUI.color(for: viewModel.property.property_type))
                    }
                }
                if let address = viewModel.property.address_line1, !address.isEmpty {
                    LabeledContent {
                        Text(address)
                    } label: {
                        Label("property_sheet.address1", systemImage: "mappin.and.ellipse")
                    }
                }
                LabeledContent {
                    Text("\(viewModel.property.bedrooms_count)")
                } label: {
                    Label("property_sheet.bedrooms_title", systemImage: "bed.double.fill")
                }
                LabeledContent {
                    Text(String(format: "%.1f", viewModel.property.bathrooms_count))
                } label: {
                    Label("property_sheet.bathrooms_title", systemImage: "bathtub.fill")
                }
            }

            if let desc = viewModel.property.description, !desc.isEmpty {
                Section("property_detail.about") {
                    Text(desc)
                }
            }

            Section {
                Button(action: {
                    switch viewModel.destinationForManageTeam() {
                    case .team:
                        showingManageTeam = true
                    case .paywall:
                        showingPaywall = true
                    }
                }) {
                    HStack {
                        Label("property_detail.manage_team", systemImage: "person.2.fill")
                        Spacer()
                        Text(viewModel.manageTeamStatusText)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("property_detail.rooms") {
                if !viewModel.hasLoadedInitialState {
                    ForEach(0..<3, id: \.self) { _ in
                        PropertyRoomSkeletonRow()
                    }
                } else if viewModel.isLoading && viewModel.rooms.isEmpty {
                    ForEach(0..<3, id: \.self) { _ in
                        PropertyRoomSkeletonRow()
                    }
                } else if viewModel.rooms.isEmpty {
                    Text("property_detail.no_rooms")
                    if viewModel.canEditRooms {
                        Button("property_detail.add_room") {
                            viewModel.showingAddRoom = true
                        }
                    }
                } else {
                    ForEach(viewModel.rooms) { room in
                        NavigationLink {
                            RoomInventoryView(room: room)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(room.name)
                                    Text(room.room_type?.capitalized ?? String(localized: "property_detail.room"))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: PropertyUI.roomIcon(for: room.room_type))
                                    .foregroundStyle(PropertyUI.roomColor(for: room.room_type))
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if viewModel.canEditRooms {
                                Button(role: .destructive) {
                                    confirmDeleteRoom(room)
                                } label: { Label("common.delete", systemImage: "trash") }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if viewModel.canEditRooms {
                                Button { editingRoom = room } label: { Label("common.edit", systemImage: "pencil") }
                                .tint(.accentColor)
                            }
                        }
                    }
                }
            }

            if !viewModel.hasLoadedInitialState {
                Section("property_detail.recent_activity") {
                    ForEach(0..<2, id: \.self) { _ in
                        PropertyRecentInspectionSkeletonRow()
                    }
                }
            } else if !viewModel.recentInspections.isEmpty {
                Section("property_detail.recent_activity") {
                    ForEach(viewModel.recentInspections) { inspection in
                        NavigationLink {
                            if inspection.status == "in_progress" {
                                InspectionHubView(inspection: inspection)
                            } else {
                                InspectionReportView(inspection: inspection)
                            }
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                                    Text(AppFormatter.formatDate(inspection.started_at))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(inspection.status.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: AppFormatter.inspectionTypeIcon(for: inspection.inspection_type))
                                    .foregroundStyle(AppFormatter.inspectionTypeColor(for: inspection.inspection_type))
                            }
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(viewModel.property.name)
        .applyInlineNavigationTitleIfSupported()
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                if viewModel.property.canEditProperty || viewModel.property.canDeleteProperty {
                    Menu {
                        if viewModel.property.canEditProperty {
                            Button {
                                editingProperty = true
                            } label: {
                                Label("common.edit", systemImage: "pencil")
                            }
                        }

                        if viewModel.property.canDeleteProperty {
                            Button(role: .destructive) {
                                confirmDeleteProperty()
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
#else
            ToolbarItem(placement: .automatic) {
                if viewModel.property.canEditProperty || viewModel.property.canDeleteProperty {
                    Menu {
                        if viewModel.property.canEditProperty {
                            Button {
                                editingProperty = true
                            } label: {
                                Label("common.edit", systemImage: "pencil")
                            }
                        }

                        if viewModel.property.canDeleteProperty {
                            Button(role: .destructive) {
                                confirmDeleteProperty()
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
#endif
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.showingAddRoom = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("property_detail.add_room")
                    }
                }
                .opacity(viewModel.canEditRooms ? 1 : 0)
                .disabled(!viewModel.canEditRooms)
            }
        }
        .alert("property_detail.active_inspection_title", isPresented: $showingRoomActiveInspectionAlert) {
            Button("common.cancel", role: .cancel) { roomToDeleteOffsets = nil }
            Button("property.delete.anyway", role: .destructive) { showingRoomDeleteAlert = true }
        } message: {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("property_detail.active_inspection_message", comment: ""),
                roomActiveInspectionItemCount
            ))
        }
        .alert("property.delete.active_title", isPresented: $showingPropertyActiveInspectionAlert) {
            Button("common.cancel", role: .cancel) { }
            Button("property.delete.anyway", role: .destructive) {
                showingPropertyDeleteAlert = true
            }
        } message: {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("property.delete.active_message", comment: ""),
                propertyActiveInspectionCount
            ))
        }
        .alert("property.delete.title", isPresented: $showingPropertyDeleteAlert) {
            Button("common.cancel", role: .cancel) { }
            Button("common.delete", role: .destructive) {
                Task {
                    HapticManager.shared.impact(style: .medium)
                    let deleted = await viewModel.deleteProperty()
                    HapticManager.shared.notification(type: deleted ? .success : .error)
                    if deleted {
                        dismiss()
                    }
                }
            }
        } message: {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("property.delete.message", comment: ""),
                viewModel.property.name
            ))
        }
        .alert("property_detail.delete_room_title", isPresented: $showingRoomDeleteAlert) {
            Button("common.cancel", role: .cancel) {
                roomToDeleteOffsets = nil
            }
            Button("common.delete", role: .destructive) {
                if let offsets = roomToDeleteOffsets {
                    HapticManager.shared.impact(style: .medium)
                    Task {
                        await viewModel.deleteRooms(at: offsets)
                        HapticManager.shared.notification(type: .success)
                    }
                }
                roomToDeleteOffsets = nil
            }
        } message: {
            Text("property_detail.delete_room_message")
        }
        .sheet(isPresented: $viewModel.showingAddRoom) {
            AddRoomSheet(propertyId: viewModel.property.id) {
                Task { await viewModel.fetchRooms() }
            }
        }
        .sheet(isPresented: $showingManageTeam, onDismiss: {
            if didLeaveProperty { dismiss() }
        }) {
            ManageTeamSheet(property: viewModel.property, isOwner: viewModel.isOwner, isManager: viewModel.isManager, didLeave: $didLeaveProperty)
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .sheet(isPresented: $editingProperty) {
            EditPropertySheet(propertyId: viewModel.property.id) {
                Task {
                    await viewModel.fetchData()
                }
            }
        }
        .sheet(item: $editingRoom) { room in
            EditRoomSheet(room: room) {
                Task { await viewModel.fetchRooms() }
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
        .refreshable {
            await viewModel.fetchData(showLoadingState: false)
        }
    }
    
    private func confirmDeleteRoom(_ room: PropertyRoomModel) {
        guard let index = viewModel.rooms.firstIndex(where: { $0.id == room.id }) else { return }
        roomToDeleteOffsets = IndexSet(integer: index)
        Task {
            let count = await viewModel.activeInspectionItemCount(at: roomToDeleteOffsets!)
            if count > 0 {
                roomActiveInspectionItemCount = count
                showingRoomActiveInspectionAlert = true
            } else {
                showingRoomDeleteAlert = true
            }
        }
    }

    private func confirmDeleteProperty() {
        Task {
            let count = await viewModel.activeInspectionCount()
            if count > 0 {
                propertyActiveInspectionCount = count
                showingPropertyActiveInspectionAlert = true
            } else {
                showingPropertyDeleteAlert = true
            }
        }
    }
}

private struct PropertyRoomSkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 150, height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 90, height: 13)
        }
        .padding(.vertical, 4)
    }
}

private struct PropertyRecentInspectionSkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 170, height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 110, height: 13)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 80, height: 12)
        }
        .padding(.vertical, 4)
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
