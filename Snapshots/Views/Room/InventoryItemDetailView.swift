import SwiftUI

struct InventoryItemDetailView: View {
    @State private var viewModel: InventoryItemDetailViewModel
    
    init(item: RoomInventoryItemModel) {
        _viewModel = State(initialValue: InventoryItemDetailViewModel(item: item))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Hero Section
                heroSection
                
                // MARK: - Specs Section
                if let desc = viewModel.item.description, !desc.isEmpty {
                    specsSection(desc)
                }
                
                // MARK: - Status History
                historySection
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchHistory()
        }
    }
    
    // MARK: - Subviews
    
    private var heroSection: some View {
        VStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.gradient.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 60))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor.gradient)
            }
            .padding(.top, 20)
            
            VStack(spacing: 4) {
                Text(viewModel.item.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 8) {
                    Text("QTY \(viewModel.item.expected_qty)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                    
                    Text("ID: \(viewModel.item.id.uuidString.prefix(8).uppercased())")
                        .font(.caption2)
                        .monospaced()
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    private func specsSection(_ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes & Specs")
                .font(.headline)
            
            Text(desc)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Condition History")
                .font(.headline)
                .padding(.horizontal)
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No past inspection records.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.history) { record in
                        HStack(spacing: 16) {
                            Image(systemName: StatusUI.icon(for: record.status))
                                .font(.title3)
                                .foregroundColor(StatusUI.color(for: record.status))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.status.capitalized)
                                    .fontWeight(.bold)
                                Text(AppFormatter.formatDate(record.updated_at))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if let notes = record.notes, !notes.isEmpty {
                                Image(systemName: "bubble.left.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
