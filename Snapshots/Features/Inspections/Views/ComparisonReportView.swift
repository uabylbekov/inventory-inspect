import SwiftUI
import Supabase
import UniformTypeIdentifiers

struct ComparisonReportView: View {
    @State private var viewModel: ComparisonReportViewModel
    @State private var exportDocument: ExportedPDFDocument?
    @State private var exportFilename = ""
    @State private var showingExporter = false
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
            } else if !viewModel.hasLoadedInitialState || (viewModel.isLoading && viewModel.changedItems.isEmpty && viewModel.unchangedItems.isEmpty) {
                Section {
                    ForEach(0..<3, id: \.self) { _ in
                        ComparisonDiffSkeletonRow()
                    }
                } header: {
                    Text("comparison.changes_found")
                }
            } else if viewModel.changedItems.isEmpty && viewModel.unchangedItems.isEmpty {
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
        .animation(.none, value: viewModel.isLoading)
        .navigationTitle("comparison.title")
        .applyInlineNavigationTitleIfSupported()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        let pdf = await viewModel.generatePDF()
                        exportDocument = ExportedPDFDocument(data: pdf.data)
                        exportFilename = pdf.filename
                        showingExporter = true
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
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .pdf,
            defaultFilename: exportFilename
        ) { _ in
            exportDocument = nil
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .task {
            await viewModel.loadInitialData()
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
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.platformSecondarySystemBackground)

                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: 110)
                                    .padding(6)
                            }
                            .frame(maxWidth: 220)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .adaptiveImagePresentation(isPresented: $showOldImage) {
                            FullScreenImageView(image: .remote(url))
                        }
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.platformGray5)
                            .frame(width: 220, height: 110)
                    }
                }

                if let newImg = diff.newImage, let url = URL(string: newImg) {
                    CachedAsyncImage(url: url, width: 300) { image in
                        Button { showNewImage = true } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.platformSecondarySystemBackground)

                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: 110)
                                    .padding(6)
                            }
                            .frame(maxWidth: 220)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .adaptiveImagePresentation(isPresented: $showNewImage) {
                            FullScreenImageView(image: .remote(url))
                        }
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.platformGray5)
                            .frame(width: 220, height: 110)
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

private struct ComparisonDiffSkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 170, height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 120, height: 13)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 150, height: 13)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.08))
                .frame(width: 220, height: 110)
        }
        .padding(.vertical, 4)
        .redacted(reason: .placeholder)
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

    @ViewBuilder
    func adaptiveImagePresentation<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
#if os(iOS)
        self.fullScreenCover(isPresented: isPresented, content: content)
#else
        self.sheet(isPresented: isPresented, content: content)
#endif
    }
}
