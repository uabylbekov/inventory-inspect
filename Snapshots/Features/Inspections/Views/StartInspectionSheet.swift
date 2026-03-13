import SwiftUI

struct StartInspectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = StartInspectionViewModel()
    @State private var showDuplicateAlert = false
    let onStarted: (() -> Void)?

    init(preloadedProperties: [PropertyModel] = [], onStarted: (() -> Void)? = nil) {
        _viewModel = State(initialValue: StartInspectionViewModel(preloadedProperties: preloadedProperties))
        self.onStarted = onStarted
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                if viewModel.isLoadingProperties {
                    Section {
                        ProgressView("start_inspection.loading_properties")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if viewModel.properties.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "start_inspection.empty.title",
                            systemImage: "building.2",
                            description: Text("start_inspection.empty.description")
                        )
                    }
                } else {
                    Section("start_inspection.select_property") {
                        ForEach(viewModel.properties) { property in
                            Button {
                                viewModel.selectedPropertyId = property.id
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: PropertyUI.icon(for: property.property_type))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20, alignment: .center)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(property.name)
                                        Text(property.address_line1 ?? String(localized: "property.no_address"))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()

                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.tint)
                                        .opacity(viewModel.selectedPropertyId == property.id ? 1 : 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.primary)
                        }
                    }

                    Section("start_inspection.type_section") {
                        inspectionTypeOption(
                            title: String(localized: "start_inspection.type.routine.title"),
                            tip: String(localized: "start_inspection.type.routine.tip"),
                            value: "routine"
                        )
                        inspectionTypeOption(
                            title: String(localized: "start_inspection.type.check_in.title"),
                            tip: String(localized: "start_inspection.type.check_in.tip"),
                            value: "move-in"
                        )
                        inspectionTypeOption(
                            title: String(localized: "start_inspection.type.check_out.title"),
                            tip: String(localized: "start_inspection.type.check_out.tip"),
                            value: "move-out"
                        )
                    }

                    if let activeId = viewModel.activeInspectionId {
                        Section("start_inspection.active.section") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("start_inspection.active.description")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    dismiss()
                                    NotificationCenter.default.post(name: AppFormatter.joinInspectionNotification, object: activeId)
                                }) {
                                    Text("start_inspection.active.join")
                                        .frame(maxWidth: .infinity)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("start_inspection.title")
                        .font(.body)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .font(.body)
                }
                if viewModel.activeInspectionId == nil && !viewModel.properties.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: { Task { await handleStartTapped() } }) {
                            if viewModel.isSaving {
                                ProgressView()
                            } else {
                                Text("start_inspection.start")
                                    .font(.body)
                            }
                        }
                        .disabled(viewModel.selectedPropertyId == nil || viewModel.isSaving)
                    }
                }
            }
            .task {
                guard viewModel.properties.isEmpty else { return }
                await viewModel.fetchProperties()
            }
            .onChange(of: viewModel.selectedPropertyId) { _, _ in
                Task { await viewModel.checkActiveInspection() }
            }
            .alert("start_inspection.duplicate.title", isPresented: $showDuplicateAlert) {
                Button("common.cancel", role: .cancel) {}
                Button("start_inspection.duplicate.confirm", role: .destructive) {
                        Task {
                            let id = await viewModel.startInspection()
                            if id != nil { 
                                HapticManager.shared.notification(type: .success)
                                onStarted?()
                                dismiss() 
                            }
                        }
                }
            } message: {
                let typeName = viewModel.inspectionType == "move-in" ? "move-in" : "move-out"
                let format = String(localized: "start_inspection.duplicate.message %1$@")
                Text(String(format: format, locale: Locale.current, typeName))
            }
        }
    }
    
    private func handleStartTapped() async {
        HapticManager.shared.impact(style: .medium)
        let isDuplicate = await viewModel.checkForDuplicate()
        if isDuplicate {
            showDuplicateAlert = true
        } else {
            let id = await viewModel.startInspection()
            if id != nil {
                HapticManager.shared.notification(type: .success)
                onStarted?()
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func inspectionTypeOption(title: String, tip: String, value: String) -> some View {
        Button {
            viewModel.inspectionType = value
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: inspectionTypeIcon(for: value))
                    .foregroundStyle(inspectionTypeColor(for: value))
                    .frame(width: 20, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)

                    Text(tip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()

                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .opacity(viewModel.inspectionType == value ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }

    private func inspectionTypeIcon(for value: String) -> String {
        AppFormatter.inspectionTypeIcon(for: value)
    }

    private func inspectionTypeColor(for value: String) -> Color {
        AppFormatter.inspectionTypeColor(for: value)
    }
}
