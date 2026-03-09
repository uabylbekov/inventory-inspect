import SwiftUI

struct AddRoomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddRoomViewModel
    
    init(propertyId: UUID) {
        _viewModel = State(initialValue: AddRoomViewModel(propertyId: propertyId))
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Room Details") {
                    TextField("Room Name (e.g. Master Bedroom)", text: $viewModel.name)
                    
                    Picker("Room Type", selection: $viewModel.roomType) {
                        Text("Bedroom").tag("Bedroom")
                        Text("Bathroom").tag("Bathroom")
                        Text("Kitchen").tag("Kitchen")
                        Text("Living Room").tag("Living Room")
                        Text("Dining Room").tag("Dining Room")
                        Text("Office").tag("Office")
                        Text("Outdoor Space").tag("Outdoor Space")
                        Text("Other").tag("Other")
                    }
                    
                    TextField("Description (e.g. South facing windows)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button(action: {
                        Task {
                            HapticManager.shared.impact(style: .medium)
                            let success = await viewModel.saveToSupabase()
                            if success {
                                HapticManager.shared.notification(type: .success)
                                dismiss()
                            } else {
                                HapticManager.shared.notification(type: .error)
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Add Room")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.isSaveDisabled)
                    .listRowBackground(viewModel.isSaveDisabled ? Color.secondary.opacity(0.1) : Color.accentColor)
                    .foregroundColor(viewModel.isSaveDisabled ? .secondary : .white)
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
            .navigationTitle("Add Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
