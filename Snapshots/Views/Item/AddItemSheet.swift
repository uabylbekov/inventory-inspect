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
                Section("item_sheet.details") {
                    TextField("item_sheet.name_placeholder", text: $viewModel.name)
                    
                    TextField("item_sheet.description_placeholder", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Stepper(String.localizedStringWithFormat(NSLocalizedString("item_sheet.expected_quantity", comment: ""), viewModel.expectedQty), value: $viewModel.expectedQty, in: 1...100)
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
                            Text("item_sheet.add_inventory_item")
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
            .navigationTitle("item_sheet.add_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }
}
