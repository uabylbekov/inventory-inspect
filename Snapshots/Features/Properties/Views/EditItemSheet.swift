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
                    TextField("item_sheet.description_placeholder", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
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
            .applyInlineNavigationTitleIfSupported()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: handleSave) {
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
