import SwiftUI
import Supabase

struct ComparisonReportView: View {
    @State private var viewModel: ComparisonReportViewModel
    @State private var pdfShareItem: ShareablePDF?
    @State private var showingPaywall = false
    
    init(base: InspectionModel, current: InspectionModel) {
        _viewModel = State(initialValue: ComparisonReportViewModel(base: base, current: current))
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                LabeledContent("comparison.previous", value: "\(AppFormatter.formatInspectionType(viewModel.older.inspection_type)) • \(AppFormatter.formatDate(viewModel.older.completed_at ?? viewModel.older.started_at))")
                LabeledContent("comparison.current", value: "\(AppFormatter.formatInspectionType(viewModel.newer.inspection_type)) • \(AppFormatter.formatDate(viewModel.newer.completed_at ?? viewModel.newer.started_at))")
            }
            .redacted(reason: viewModel.isLoading ? .placeholder : [])
            
            if let error = viewModel.errorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("comparison.failed_title")
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("common.try_again") {
                            Task { await viewModel.fetchComparison() }
                        }
                    }
                }
            } else if !viewModel.isLoading && viewModel.changedItems.isEmpty && viewModel.unchangedItems.isEmpty {
                Section {
                    ContentUnavailableView(
                        "comparison.empty_title",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("comparison.empty_message")
                    )
                }
            } else {
                if !viewModel.changedItems.isEmpty {
                    Section {
                        ForEach(viewModel.changedItems) { diff in
                            DiffRowView(diff: diff)
                        }
                    } header: {
                        Text(String.localizedStringWithFormat(
                            NSLocalizedString("comparison.changes_found", comment: ""),
                            viewModel.changedItems.count
                        ))
                            .foregroundColor(.red)
                    }
                }
                
                if !viewModel.unchangedItems.isEmpty {
                    Section {
                        ForEach(viewModel.unchangedItems) { diff in
                            DiffRowView(diff: diff)
                        }
                    } header: {
                        Text(String.localizedStringWithFormat(
                            NSLocalizedString("comparison.unchanged_items", comment: ""),
                            viewModel.unchangedItems.count
                        ))
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()
                    ProgressView("comparison.loading")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .animation(.none, value: viewModel.isLoading)
        .navigationTitle("comparison.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        let pdf = await viewModel.generatePDF()
                        pdfShareItem = ShareablePDF(data: pdf.data, filename: pdf.filename)
                    }
                } label: {
                    if viewModel.isGeneratingPDF {
                        ProgressView()
                    } else {
                        Label("comparison.share_pdf", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isGeneratingPDF)
            }
        }
        .sheet(item: $pdfShareItem) { pdf in
            ShareSheet(data: pdf.data, filename: pdf.filename)
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .task {
            await viewModel.fetchComparison()
        }
    }
    
    // MARK: - Diff Row UI
    
    private struct DiffRowView: View {
        let diff: DiffItem
        @State private var showOldImage = false
        @State private var showNewImage = false

        private var oldStatusColor: Color {
            color(for: diff.oldStatus)
        }

        private var newStatusColor: Color {
            color(for: diff.newStatus)
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(diff.itemName)
                Text(diff.roomName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LabeledContent("comparison.previous") {
                    Text(displayStatus(diff.oldStatus))
                        .foregroundColor(oldStatusColor)
                }
                LabeledContent("comparison.current") {
                    Text(displayCurrentStatus)
                        .foregroundColor(newStatusColor)
                }

                if let oldImg = diff.oldImage, let url = URL(string: oldImg) {
                    CachedAsyncImage(url: url, width: 300) { image in
                        Button { showOldImage = true } label: {
                            image.resizable().scaledToFill().frame(height: 90).clipped()
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .fullScreenCover(isPresented: $showOldImage) {
                            FullScreenImageView(image: .remote(url))
                        }
                    } placeholder: {
                        Color(UIColor.systemGray5).frame(height: 90)
                    }
                }

                if let newImg = diff.newImage, let url = URL(string: newImg) {
                    CachedAsyncImage(url: url, width: 300) { image in
                        Button { showNewImage = true } label: {
                            image.resizable().scaledToFill().frame(height: 90).clipped()
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .fullScreenCover(isPresented: $showNewImage) {
                            FullScreenImageView(image: .remote(url))
                        }
                    } placeholder: {
                        Color(UIColor.systemGray5).frame(height: 90)
                    }
                }

                if let newNotes = diff.newNotes, !newNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("comparison.current_notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(newNotes)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .opacity(diff.oldStatus == diff.newStatus && (diff.newNotes == nil || diff.newNotes?.isEmpty == true) ? 0.72 : 1)
        }

        private func color(for status: String) -> Color {
            switch status {
            case "present":
                return .green
            case "missing":
                return .orange
            case "damaged":
                return .red
            case "resolved":
                return .blue
            default:
                return .secondary
            }
        }

        private func displayStatus(_ status: String) -> String {
            switch status {
            case "present":
                return String(localized: "report.present_intact")
            case "missing":
                return String(localized: "inspection_item.status.missing")
            case "damaged":
                return String(localized: "inspection_item.status.damaged")
            case "resolved":
                return String(localized: "pdf.summary.resolved")
            default:
                return status.replacingOccurrences(of: "_", with: " ").capitalized
            }
        }

        private var displayCurrentStatus: String {
            if diff.newStatus == "resolved",
               let previousStatus = diff.newPreviousStatus,
               isResolvableIssue(previousStatus) {
                return "Resolved from \(displayStatus(previousStatus))"
            }
            return displayStatus(diff.newStatus)
        }

        private func isResolvableIssue(_ status: String) -> Bool {
            status == "missing" || status == "damaged"
        }
    }
}
