import SwiftUI
import Supabase

struct ComparisonReportView: View {
    @State private var viewModel: ComparisonReportViewModel
    @State private var previewPDFData: Data?
    @State private var exportFilename = ""
    @State private var showingPDFPreview = false
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
                    Label("comparison.changes_found", systemImage: "arrow.triangle.2.circlepath")
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
                    Label(
                        String.localizedStringWithFormat(
                            NSLocalizedString("comparison.changes_found", comment: ""),
                            viewModel.changedItems.count
                        ),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .foregroundStyle(.orange)

                    ForEach(viewModel.changedItems) { diff in
                        Section {
                            DiffRowView(diff: diff, sectionKind: .changed)
                        } header: {
                            itemHeader(diff: diff)
                        }
                    }
                }
                
                if !viewModel.unchangedItems.isEmpty {
                    Label(
                        String.localizedStringWithFormat(
                            NSLocalizedString("comparison.unchanged_items", comment: ""),
                            viewModel.unchangedItems.count
                        ),
                        systemImage: "checkmark.circle"
                    )

                    ForEach(viewModel.unchangedItems) { diff in
                        Section {
                            DiffRowView(diff: diff, sectionKind: .unchanged)
                        } header: {
                            itemHeader(diff: diff)
                        }
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
                        previewPDFData = pdf.data
                        exportFilename = pdf.filename
                        showingPDFPreview = true
                    }
                } label: {
                    if viewModel.isGeneratingPDF {
                        ProgressView()
                    } else {
                        Label("comparison.share_pdf", systemImage: "doc.badge.plus")
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isGeneratingPDF)
            }
        }
        .sheet(isPresented: $showingPDFPreview) {
            if let previewPDFData {
                PDFPreviewSheet(
                    data: previewPDFData,
                    title: exportFilename
                )
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .task {
            await viewModel.loadInitialData()
        }
    }

    @ViewBuilder
    private func itemHeader(diff: DiffItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(diff.itemName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(diff.roomName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
    }
    
    // MARK: - Diff Row UI
    
    private struct DiffRowView: View {
        enum SectionKind {
            case changed
            case unchanged
        }

        let diff: DiffItem
        let sectionKind: SectionKind
        @State private var showOldImage = false
        @State private var showNewImage = false

        private var shouldShowPhotoColumn: Bool {
            hasPhoto(diff.oldImage) || hasPhoto(diff.newImage)
        }

        private var oldStatusColor: Color {
            color(for: diff.oldStatus)
        }

        private var newStatusColor: Color {
            color(for: diff.newStatus)
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                comparisonStatusRow(
                    titleKey: "comparison.previous",
                    statusText: displayStatus(diff.oldStatus),
                    color: oldStatusColor,
                    imagePath: diff.oldImage,
                    showPhotoColumn: shouldShowPhotoColumn,
                    isPresented: $showOldImage
                )

                Divider()

                comparisonStatusRow(
                    titleKey: "comparison.current",
                    statusText: displayCurrentStatus,
                    color: newStatusColor,
                    imagePath: diff.newImage,
                    showPhotoColumn: shouldShowPhotoColumn,
                    isPresented: $showNewImage
                )

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
            .opacity(sectionKind == .unchanged ? 0.72 : 1)
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
                return String.localizedStringWithFormat(
                    NSLocalizedString("pdf.status.resolved_from", comment: ""),
                    displayStatus(previousStatus)
                )
            }
            return displayStatus(diff.newStatus)
        }

        private func isResolvableIssue(_ status: String) -> Bool {
            status == "missing" || status == "damaged"
        }

        private func hasPhoto(_ imagePath: String?) -> Bool {
            guard let imagePath else { return false }
            return !imagePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        private func comparisonStatusRow(
            titleKey: LocalizedStringKey,
            statusText: String,
            color: Color,
            imagePath: String?,
            showPhotoColumn: Bool,
            isPresented: Binding<Bool>
        ) -> some View {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(statusText)
                        .foregroundColor(color)
                }

                Spacer(minLength: 0)

                if showPhotoColumn {
                    if let imagePath {
                        comparisonThumbnail(path: imagePath, isPresented: isPresented)
                    } else {
                        noPhotoPlaceholder()
                    }
                }
            }
        }

        @ViewBuilder
        private func comparisonThumbnail(path: String, isPresented: Binding<Bool>) -> some View {
            InspectionEvidenceAsyncImage(imagePath: path, width: 300) { image in
                Button { isPresented.wrappedValue = true } label: {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .adaptiveImagePresentation(isPresented: isPresented) {
                    InspectionEvidenceFullScreenView(imagePath: path)
                }
            } placeholder: {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.platformGray5)
                    .frame(width: 96, height: 72)
            }
        }

        private func noPhotoPlaceholder() -> some View {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.platformGray5)
                Text("comparison.no_photo")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 96, height: 72)
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
