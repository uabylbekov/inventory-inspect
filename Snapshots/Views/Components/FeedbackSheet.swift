import SwiftUI

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: FeedbackViewModel

    init(userName: String, personalTier: String) {
        _viewModel = State(initialValue: FeedbackViewModel(userName: userName, personalTier: personalTier))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    Picker("feedback.type", selection: $viewModel.selectedCategory) {
                        ForEach(FeedbackViewModel.Category.allCases) { category in
                            Text(category.titleKey).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                } footer: {
                    Text("feedback.type_footer")
                }

                Section("feedback.message") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.message)
                            .frame(minHeight: 180)

                        if viewModel.trimmedMessage.isEmpty {
                            Text("feedback.message_placeholder")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }

                    HStack {
                        Text("feedback.minimum_length")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(viewModel.trimmedMessage.count)")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .navigationTitle("feedback.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .disabled(viewModel.isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { Task { await viewModel.submit() } }) {
                        if viewModel.isSubmitting {
                            ProgressView()
                        } else {
                            Text("feedback.submit")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isSubmitDisabled)
                }
            }
            .interactiveDismissDisabled(viewModel.isSubmitting)
            .alert("feedback.success.title", isPresented: $viewModel.didSubmit) {
                Button("common.done") { dismiss() }
            } message: {
                Text("feedback.success.message")
            }
        }
        .presentationDetents([.medium, .large])
    }
}
