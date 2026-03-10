import SwiftUI

struct EditItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditItemViewModel
    let onSaved: (() -> Void)?
    
    init(item: RoomInventoryItemModel, onSaved: (() -> Void)? = nil) {
        _viewModel = State(initialValue: EditItemViewModel(item: item))
        self.onSaved = onSaved
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("item_sheet.edit_details")) {
                    TextField("item_sheet.name_placeholder", text: $viewModel.name)
                    TextField("item_sheet.description_placeholder", text: $viewModel.description)
                    Stepper(String.localizedStringWithFormat(NSLocalizedString("item_sheet.expected_quantity", comment: ""), viewModel.expectedQty), value: $viewModel.expectedQty, in: 1...100)
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("item_sheet.edit_title")
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
                                onSaved?()
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
