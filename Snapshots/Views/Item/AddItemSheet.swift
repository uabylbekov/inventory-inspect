import SwiftUI

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddItemViewModel
    
    init(roomId: UUID) {
        _viewModel = State(initialValue: AddItemViewModel(roomId: roomId))
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Item Details") {
                    TextField("Item Name (e.g. Sofa, Coffeemaker)", text: $viewModel.name)
                    
                    TextField("Description (e.g. Black leather, Model: X1)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Stepper("Expected Quantity: \(viewModel.expectedQty)", value: $viewModel.expectedQty, in: 1...100)
                }
                
                Section {
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
                        HStack(spacing: 8) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Add Inventory Item")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.isSaveDisabled)
                    .listRowBackground(viewModel.isSaveDisabled ? Color.secondary.opacity(0.1) : Color.accentColor)
                    .foregroundColor(viewModel.isSaveDisabled ? .secondary : .white)
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
