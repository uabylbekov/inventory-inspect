import SwiftUI

struct AddRoomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddRoomViewModel
    
    init(propertyId: UUID) {
        // Initialize the view model with the correct property ID
        _viewModel = State(initialValue: AddRoomViewModel(propertyId: propertyId))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Room Details")) {
                    TextField("Room Name (e.g. Master Bedroom)", text: $viewModel.name)
                    TextField("Description (e.g. South facing windows)", text: $viewModel.description)
                    
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
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Add Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
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
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(viewModel.isSaveDisabled)
                }
            }
        }
    }
}
