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
            List {
                if viewModel.isLoadingProperties {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("start_inspection.loading_properties")
                            Spacer()
                        }
                    }
                } else if viewModel.properties.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "start_inspection.empty.title",
                            systemImage: "building.2",
                            description: Text("start_inspection.empty.description")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    // MARK: - Property Selection
                    Section("start_inspection.property_section") {
                        Picker("start_inspection.select_property", selection: $viewModel.selectedPropertyId) {
                            Text("start_inspection.select_property_placeholder").tag(nil as UUID?)
                            ForEach(viewModel.properties) { property in
                                Text(property.name).tag(property.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // MARK: - Type Selection
                    Section("start_inspection.type_section") {
                        Picker("start_inspection.type_section", selection: $viewModel.inspectionType) {
                            Text("start_inspection.type.routine.title").tag("routine")
                            Text("start_inspection.type.check_in.title").tag("check-in")
                            Text("start_inspection.type.check_out.title").tag("check-out")
                        }

                        Text(selectedInspectionTip)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // MARK: - Active Sessions
                    if let activeId = viewModel.activeInspectionId {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("start_inspection.active.label", systemImage: "person.2.fill")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                
                                Text("start_inspection.active.description")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    dismiss()
                                    NotificationCenter.default.post(name: AppFormatter.joinInspectionNotification, object: activeId)
                                }) {
                                    Text("start_inspection.active.join")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 4)
                        } header: {
                            Text("start_inspection.active.section")
                        }
                    }
                    
                    // MARK: - Actions
                    if viewModel.activeInspectionId == nil {
                        Section {
                            Button(action: { Task { await handleStartTapped() } }) {
                                HStack(spacing: 8) {
                                    if viewModel.isSaving {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    Text("start_inspection.start")
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(viewModel.selectedPropertyId == nil || viewModel.isSaving)
                            .listRowBackground(viewModel.selectedPropertyId == nil ? Color.secondary.opacity(0.1) : Color.accentColor)
                            .foregroundColor(viewModel.selectedPropertyId == nil ? .secondary : .white)
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
            .listStyle(.insetGrouped)
            .navigationTitle("start_inspection.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
            .task {
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
                let typeName = viewModel.inspectionType == "check-in"
                    ? String(localized: "start_inspection.duplicate.type.check_in")
                    : String(localized: "start_inspection.duplicate.type.check_out")
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

    private var selectedInspectionTip: String {
        switch viewModel.inspectionType {
        case "check-in":
            return String(localized: "start_inspection.type.check_in.tip")
        case "check-out":
            return String(localized: "start_inspection.type.check_out.tip")
        default:
            return String(localized: "start_inspection.type.routine.tip")
        }
    }
}
