import SwiftUI

struct AddRoomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddRoomViewModel
    let onSaved: (() -> Void)?
    
    init(propertyId: UUID, onSaved: (() -> Void)? = nil) {
        _viewModel = State(initialValue: AddRoomViewModel(propertyId: propertyId))
        self.onSaved = onSaved
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("room_sheet.details") {
                    TextField("room_sheet.name_placeholder", text: $viewModel.name)

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

                    TextField("room_sheet.description_placeholder", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("property_detail.add_room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("property_detail.add_room")
                        .font(.body)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .font(.body)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: handleSave) {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("common.save")
                                .font(.body)
                        }
                    }
                    .disabled(viewModel.isSaveDisabled)
                }
            }
        }
    }

    private func handleSave() {
        Task {
            HapticManager.shared.impact(style: .medium)
            let success = await viewModel.saveToSupabase()
            if success {
                HapticManager.shared.notification(type: .success)
                onSaved?()
                dismiss()
            } else {
                HapticManager.shared.notification(type: .error)
            }
        }
    }
}
