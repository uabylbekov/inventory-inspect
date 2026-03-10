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
                Section(header: Text("room_sheet.edit_details")) {
                    TextField("room_sheet.name_placeholder", text: $viewModel.name)
                    TextField("room_sheet.description_placeholder", text: $viewModel.description)
                    
                    Picker("room_sheet.type", selection: $viewModel.roomType) {
                        Text("room_type.bedroom").tag("Bedroom")
                        Text("room_type.bathroom").tag("Bathroom")
                        Text("room_type.kitchen").tag("Kitchen")
                        Text("room_type.living_room").tag("Living Room")
                        Text("room_type.dining_room").tag("Dining Room")
                        Text("room_type.office").tag("Office")
                        Text("room_type.outdoor_space").tag("Outdoor Space")
                        Text("room_type.other").tag("Other")
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
            .navigationTitle("room_sheet.edit_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
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
                            Text("common.save")
                        }
                    }
                    .disabled(viewModel.isSaveDisabled)
                }
            }
        }
    }
}
