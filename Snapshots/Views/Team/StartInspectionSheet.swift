import SwiftUI

struct StartInspectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = StartInspectionViewModel()
    @State private var showDuplicateAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isLoadingProperties {
                    loadingRow
                } else if viewModel.properties.isEmpty {
                    emptyPropertiesSection
                } else {
                    propertySelectionSection
                    inspectionTypeSection
                    
                    if let activeId = viewModel.activeInspectionId {
                        activeSessionSection(activeId: activeId)
                    }
                    
                    if viewModel.activeInspectionId == nil {
                        startActionSection
                    }
                }
                
                if let error = viewModel.errorMessage {
                    errorSection(error)
                }
            }
            .navigationTitle("New Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await viewModel.fetchProperties() }
            .onChange(of: viewModel.selectedPropertyId) { _, _ in
                Task { await viewModel.checkActiveInspection() }
            }
            .alert("Inspection Already Exists", isPresented: $showDuplicateAlert) {
                duplicateAlertActions
            } message: {
                duplicateAlertMessage
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingRow: some View {
        ProgressView()
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
    }
    
    private var emptyPropertiesSection: some View {
        Section {
            Text("You don't have any properties yet.")
                .foregroundColor(.secondary)
        }
    }
    
    private var propertySelectionSection: some View {
        Section(header: Text("Select Property")) {
            ForEach(viewModel.properties) { property in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectedPropertyId = property.id
                    }
                    HapticManager.shared.impact(style: .light)
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(property.name)
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            if let address = property.address_line1, !address.isEmpty {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        RadioButtonIndicator(isSelected: viewModel.selectedPropertyId == property.id)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var inspectionTypeSection: some View {
        Section(header: Text("Inspection Type")) {
            VStack(spacing: 0) {
                let types: [(String, String, String, String)] = [
                    ("Check In", "door.left.hand.open", "check-in", "Document condition before a new tenant moves in to set the baseline."),
                    ("Check Out", "door.right.hand.closed", "check-out", "Assess condition after move-out to identify deductions & repairs."),
                    ("Routine", "wrench.adjustable.fill", "routine", "Periodic check to catch maintenance issues early and ensure safety.")
                ]

                ForEach(types, id: \.2) { name, icon, value, description in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.inspectionType = value
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(viewModel.inspectionType == value ? Color.accentColor : Color.secondary.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundColor(viewModel.inspectionType == value ? .white : .secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(name)
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.primary)
                                
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                            
                            RadioButtonIndicator(isSelected: viewModel.inspectionType == value)
                                .padding(.top, 4)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if value != types.last?.2 {
                        Divider()
                    }
                }
            }
        }
    }
    
    private func activeSessionSection(activeId: UUID) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Inspection In Progress", systemImage: "person.2.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                Text("A team member is already inspecting this property. You can join them to split the work.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    dismiss()
                    NotificationCenter.default.post(name: AppFormatter.joinInspectionNotification, object: activeId)
                }) {
                    Text("Join Existing Session")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Active Session")
        }
    }
    
    private var startActionSection: some View {
        Section {
            Button(action: { Task { await handleStartTapped() } }) {
                if viewModel.isSaving {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("Start New Inspection")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.selectedPropertyId == nil || viewModel.isSaving)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
    
    private func errorSection(_ error: String) -> some View {
        Section {
            Text(error)
                .foregroundColor(.red)
                .font(.footnote)
        }
    }
    
    private var duplicateAlertActions: some View {
        Group {
            Button("Cancel", role: .cancel) {}
            Button("Start Anyway", role: .destructive) {
                Task {
                    let id = await viewModel.startInspection()
                    if id != nil { dismiss() }
                }
            }
        }
    }
    
    private var duplicateAlertMessage: some View {
        let typeName = viewModel.inspectionType == "check-in" ? "check-in" : "check-out"
        return Text("A \(typeName) inspection for this property already exists today. Are you sure you want to create another?")
    }
    
    private func handleStartTapped() async {
        let isDuplicate = await viewModel.checkForDuplicate()
        if isDuplicate {
            showDuplicateAlert = true
        } else {
            let id = await viewModel.startInspection()
            if id != nil { dismiss() }
        }
    }
}

struct RadioButtonIndicator: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                .frame(width: 22, height: 22)
            
            if isSelected {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 12, height: 12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
