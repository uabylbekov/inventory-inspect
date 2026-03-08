import SwiftUI

struct EditItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditItemViewModel
    
    init(item: RoomInventoryItemModel) {
        _viewModel = State(initialValue: EditItemViewModel(item: item))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Edit Item Details")) {
                    TextField("Item Name (e.g. Sofa, Coffeemaker)", text: $viewModel.name)
                    TextField("Description (e.g. Black leather, Model: X1)", text: $viewModel.description)
                    Stepper("Expected Quantity: \(viewModel.expectedQty)", value: $viewModel.expectedQty, in: 1...100)
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Edit Item")
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
