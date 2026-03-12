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
                    Section("Select property") {
                        ForEach(viewModel.properties) { property in
                            Button {
                                viewModel.selectedPropertyId = property.id
                            } label: {
                                HStack {
                                    Image(systemName: viewModel.selectedPropertyId == property.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(viewModel.selectedPropertyId == property.id ? .accentColor : .secondary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(property.name)
                                        Text(property.address_line1 ?? String(localized: "property.no_address"))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }

                    Section("Inspection type") {
                        inspectionTypeOption(
                            title: "Routine",
                            tip: "General walkthrough to check condition, maintenance needs, and overall state of the property.",
                            value: "routine"
                        )
                        inspectionTypeOption(
                            title: "Move-in",
                            tip: "Document the property condition before a new resident or guest arrives. Creates a baseline record.",
                            value: "move-in"
                        )
                        inspectionTypeOption(
                            title: "Move-out",
                            tip: "Document the condition at departure and compare against the earlier baseline to catch changes.",
                            value: "move-out"
                        )
                    }

                    if let activeId = viewModel.activeInspectionId {
                        Section("Active inspection") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Another inspection is already in progress for this property.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    dismiss()
                                    NotificationCenter.default.post(name: AppFormatter.joinInspectionNotification, object: activeId)
                                }) {
                                    Text("Join")
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
                    Text("New Inspection")
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
                                Text("Start")
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
                Image(systemName: viewModel.inspectionType == value ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(viewModel.inspectionType == value ? .accentColor : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)

                    Text(tip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .foregroundColor(.primary)
    }
}
