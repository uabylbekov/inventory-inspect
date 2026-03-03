import SwiftUI

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddItemViewModel
    
    init(roomId: UUID) {
        _viewModel = State(initialValue: AddItemViewModel(roomId: roomId))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name (e.g. Sofa, Coffeemaker)", text: $viewModel.name)
                    
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
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        Task {
                            let success = await viewModel.saveToSupabase()
                            if success { dismiss() }
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
