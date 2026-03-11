import SwiftUI

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddItemViewModel
    let onSaved: (() -> Void)?
    
    init(roomId: UUID, onSaved: (() -> Void)? = nil) {
        _viewModel = State(initialValue: AddItemViewModel(roomId: roomId))
        self.onSaved = onSaved
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("item_sheet.details") {
                    TextField("item_sheet.name_placeholder", text: $viewModel.name)

                    TextField("item_sheet.description_placeholder", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)

                    Stepper(String.localizedStringWithFormat(NSLocalizedString("item_sheet.expected_quantity", comment: ""), viewModel.expectedQty), value: $viewModel.expectedQty, in: 1...100)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("item_sheet.add_title")
            .applyInlineNavigationTitleIfSupported()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("item_sheet.add_title")
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
