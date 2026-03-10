import SwiftUI

struct StartInspectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = StartInspectionViewModel()
    @State private var showDuplicateAlert = false
    
    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            List {
                if viewModel.isLoadingProperties {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading Properties...")
                            Spacer()
                        }
                    }
                } else if viewModel.properties.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Properties",
                            systemImage: "building.2",
                            description: Text("Add a property first before starting an inspection.")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    // MARK: - Property Selection
                    Section("Property") {
                        Picker("Select Property", selection: $viewModel.selectedPropertyId) {
                            Text("Select a property").tag(nil as UUID?)
                            ForEach(viewModel.properties) { property in
                                Text(property.name).tag(property.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // MARK: - Type Selection
                    Section("Inspection Type") {
                        InspectionTypeRow(
                            icon: "wrench.adjustable.fill",
                            iconColor: .blue,
                            title: "Routine",
                            tip: "General walkthrough to check condition, maintenance needs, and overall state of the property.",
                            isSelected: viewModel.inspectionType == "routine"
                        ) { viewModel.inspectionType = "routine" }

                        InspectionTypeRow(
                            icon: "door.left.hand.open",
                            iconColor: .green,
                            title: "Check-In",
                            tip: "Document the property condition before a new tenant or guest arrives. Creates a baseline record.",
                            isSelected: viewModel.inspectionType == "check-in"
                        ) { viewModel.inspectionType = "check-in" }

                        InspectionTypeRow(
                            icon: "door.right.hand.closed",
                            iconColor: .orange,
                            title: "Check-Out",
                            tip: "Compare against the check-in report to identify any damage or changes after a tenant or guest leaves.",
                            isSelected: viewModel.inspectionType == "check-out"
                        ) { viewModel.inspectionType = "check-out" }
                    }
                    
                    // MARK: - Active Sessions
                    if let activeId = viewModel.activeInspectionId {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Inspection In Progress", systemImage: "person.2.fill")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                
                                Text("A team member is already inspecting this property. You can join them to split the work.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    dismiss()
                                    NotificationCenter.default.post(name: AppFormatter.joinInspectionNotification, object: activeId)
                                }) {
                                    Text("Join Existing Session")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 4)
                        } header: {
                            Text("Active Session Found")
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
                                    Text("Start New Inspection")
                                        .fontWeight(.bold)
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
            .navigationTitle("New Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { 
                await viewModel.fetchProperties()
            }
            .onChange(of: viewModel.selectedPropertyId) { _, _ in
                Task { await viewModel.checkActiveInspection() }
            }
            .alert("Inspection Already Exists", isPresented: $showDuplicateAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Start Anyway", role: .destructive) {
                    Task {
                        let id = await viewModel.startInspection()
                        if id != nil { 
                            HapticManager.shared.notification(type: .success)
                            dismiss() 
                        }
                    }
                }
            } message: {
                let typeName = viewModel.inspectionType == "check-in" ? "check-in" : "check-out"
                Text("A \(typeName) inspection for this property already exists today. Are you sure you want to create another?")
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
                dismiss()
            }
        }
    }
}

private struct InspectionTypeRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let tip: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.gradient)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(tip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.vertical, 4)
        }
    }
}
