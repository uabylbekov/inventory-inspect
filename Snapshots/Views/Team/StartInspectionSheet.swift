import SwiftUI

struct StartInspectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = StartInspectionViewModel()
    @State private var showDuplicateAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isLoadingProperties {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if viewModel.properties.isEmpty {
                    Section {
                        Text("You don't have any properties yet.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section(header: Text("Select Property")) {
                        Picker("Property", selection: $viewModel.selectedPropertyId) {
                            ForEach(viewModel.properties) { property in
                                Text(property.name).tag(Optional(property.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.inline)
                    }
                    Section(header: Text("Inspection Type")) {
                        Picker("Type", selection: $viewModel.inspectionType) {
                            Text("✨ Check In").tag("check-in")
                            Text("🧹 Check Out").tag("check-out")
                            Text("🛠️ Routine").tag("routine")
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                    
                    if let activeId = viewModel.activeInspectionId {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Inspection In Progress", systemImage: "person.2.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Text("A team member is already inspecting this property. You can join them to split the work.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    // Joining just means dismissing and potentially navigating, 
                                    // but usually we want to return the ID so the parent can navigate
                                    dismiss()
                                    NotificationCenter.default.post(name: NSNotification.Name("JoinInspection"), object: activeId)
                                }) {
                                    Text("Join Existing Session")
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .controlSize(.large)
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 8)
                        } header: {
                            Text("Active Session")
                        }
                    }
                    
                    if viewModel.activeInspectionId == nil {
                        Section {
                            Button(action: {
                                Task { await handleStartTapped() }
                            }) {
                                if viewModel.isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
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
                        if id != nil { dismiss() }
                    }
                }
            } message: {
                let typeName = viewModel.inspectionType == "check-in" ? "check-in" : "check-out"
                Text("A \(typeName) inspection for this property already exists today. Are you sure you want to create another?")
            }
        }
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
