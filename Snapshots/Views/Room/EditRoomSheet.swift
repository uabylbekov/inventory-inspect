import SwiftUI

struct EditRoomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditRoomViewModel
    
    init(room: PropertyRoomModel) {
        _viewModel = State(initialValue: EditRoomViewModel(room: room))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Edit Room Details")) {
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
            .navigationTitle("Edit Room")
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
                            Text("Save")
                        }
                    }
                    .disabled(viewModel.isSaveDisabled)
                }
            }
        }
    }
}
