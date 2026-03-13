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
                        roomTypeOption("room_type.bedroom", value: "Bedroom")
                        roomTypeOption("room_type.bathroom", value: "Bathroom")
                        roomTypeOption("room_type.kitchen", value: "Kitchen")
                        roomTypeOption("room_type.living_room", value: "Living Room")
                        roomTypeOption("room_type.dining_room", value: "Dining Room")
                        roomTypeOption("room_type.office", value: "Office")
                        roomTypeOption("room_type.outdoor_space", value: "Outdoor Space")
                        roomTypeOption("room_type.other", value: "Other")
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
            .applyInlineNavigationTitleIfSupported()
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

    @ViewBuilder
    private func roomTypeOption(_ titleKey: LocalizedStringKey, value: String) -> some View {
        Label {
            Text(titleKey)
        } icon: {
            Image(systemName: PropertyUI.roomIcon(for: value))
                .foregroundStyle(PropertyUI.roomColor(for: value))
        }
        .tag(value)
    }
}

private extension View {
    @ViewBuilder
    func applyInlineNavigationTitleIfSupported() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }
}
