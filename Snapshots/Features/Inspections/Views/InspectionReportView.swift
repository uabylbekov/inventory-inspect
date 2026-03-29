import SwiftUI

struct InspectionReportView: View {
    @State private var viewModel: InspectionReportViewModel
    @State private var showingInspectionSelection = false
    @State private var previewPDFData: Data?
    @State private var exportFilename = ""
    @State private var showingPDFPreview = false
    @State private var showingPaywall = false

    init(inspection: InspectionModel) {
        _viewModel = State(initialValue: InspectionReportViewModel(inspection: inspection))
    }
    
    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            
            Section {
                if let prop = viewModel.property {
                    LabeledContent("start_inspection.property_section", value: prop.name)
                    LabeledContent("profile.address", value: prop.address_line1 ?? String(localized: "property.no_address"))
                }
                LabeledContent("feedback.type", value: AppFormatter.formatInspectionType(viewModel.inspection.inspection_type))
                LabeledContent("report.date", value: AppFormatter.formatDate(viewModel.inspection.started_at))
                if let name = viewModel.inspectorName {
                    LabeledContent("report.inspector", value: name)
                }
            }
            .redacted(reason: viewModel.isLoading ? .placeholder : [])

            if !viewModel.hasLoadedInitialState || (viewModel.isLoading && viewModel.anomalies.isEmpty && viewModel.presentItems.isEmpty && viewModel.resolvedItems.isEmpty) {
                Section {
                    ForEach(0..<3, id: \.self) { _ in
                        ReportItemSkeletonRow()
                    }
                } header: {
                    Text("report.anomalies")
                }
            } else {
                Section {
                    LabeledContent("report.anomalies", value: "\(viewModel.anomalies.count)")
                    LabeledContent("report.resolved_issues", value: "\(viewModel.resolvedItems.count)")
                    LabeledContent("report.present_intact", value: "\(viewModel.presentItems.count)")
                }
            }

            if !viewModel.anomalies.isEmpty {
                Section {
                    ForEach(viewModel.anomalies, id: \.id) { item in
                        anomalyRows(for: item)
                    }
                } header: {
                    HStack {
                        reportSectionHeader("report.anomalies", systemImage: "exclamationmark.triangle.fill", color: .orange)
                        Spacer()
                        Text("\(viewModel.anomalies.count)")
                    }
                }
            } else if !viewModel.isLoading && !viewModel.resolvedItems.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("report.resolved_title")
                            .foregroundStyle(.blue)
                        Text("report.resolved_subtitle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            } else if !viewModel.isLoading {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("report.perfect_title")
                        Text("report.perfect_subtitle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !viewModel.resolvedItems.isEmpty {
                Section {
                    ForEach(viewModel.resolvedItems, id: \.id) { item in
                        ReportItemRow(item: item, sectionKind: .resolved)
                    }
                } header: {
                    HStack {
                        reportSectionHeader("report.resolved_issues", systemImage: "checkmark.circle.fill", color: .blue)
                        Spacer()
                        Text("\(viewModel.resolvedItems.count)")
                    }
                }
            }
            
            if !viewModel.presentItems.isEmpty {
                Section {
                    ForEach(viewModel.presentItems, id: \.id) { item in
                        ReportItemRow(item: item, sectionKind: .present)
                    }
                } header: {
                    HStack {
                        reportSectionHeader("report.present_intact", systemImage: "checkmark.seal.fill", color: .green)
                        Spacer()
                        Text("\(viewModel.presentItems.count)")
                    }
                }
            }
        }
        .animation(.none, value: viewModel.isLoading)
        .navigationTitle("report.title")
        .applyInlineNavigationTitleIfSupported()
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { showingInspectionSelection = true }) {
                    Image(systemName: "shoeprints.fill")
                        .imageScale(.large)
                }
            }
#else
            ToolbarItem(placement: .automatic) {
                Button(action: { showingInspectionSelection = true }) {
                    Image(systemName: "shoeprints.fill")
                        .imageScale(.large)
                }
            }
#endif
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isGeneratingPDF {
                    ProgressView()
                } else {
                    Button(action: {
                        Task {
                            if let pdf = await viewModel.generatePDF() {
                                previewPDFData = pdf.data
                                exportFilename = pdf.filename
                                showingPDFPreview = true
                            }
                        }
                    }) {
                        Image(systemName: "doc.badge.plus")
                            .imageScale(.large)
                    }
                }
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
        .sheet(isPresented: $showingInspectionSelection) {
            CompareSelectSheet(currentInspection: viewModel.inspection)
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .task {
            await viewModel.loadInitialData()
        }
        .refreshable {
            await viewModel.fetchReportData(showLoadingState: false)
        }
    }

    @ViewBuilder
    private func anomalyRows(for item: ReportItem) -> some View {
        ReportItemRow(item: item, sectionKind: .anomalies)
        resolveRow(for: item)
    }

    private func resolveRow(for item: ReportItem) -> some View {
        Button {
            Task {
                HapticManager.shared.impact(style: .medium)
                let resolved = await viewModel.resolveAnomaly(reportItem: item)
                HapticManager.shared.notification(type: resolved ? .success : .error)
            }
        } label: {
            Text("report.mark_resolved")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    private func reportSectionHeader(_ titleKey: LocalizedStringKey, systemImage: String, color: Color) -> some View {
        Label {
            Text(titleKey)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(color)
        }
    }
}

private struct ReportItemSkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 180, height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 120, height: 13)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 90, height: 12)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 120)
        }
        .padding(.vertical, 4)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Report Item Row

struct ReportItemRow: View {
    enum SectionKind {
        case anomalies
        case resolved
        case present
    }

    let item: ReportItem
    let sectionKind: SectionKind
    @State private var showFullScreenImage = false
    
    private var status: String { item.inspectionItem.status }
    private var previousStatus: String? { item.inspectionItem.previous_status }
    
    private var statusColor: Color {
        switch effectiveStatus {
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
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: rowSymbolName)
                .imageScale(.medium)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(statusColor)
                .frame(width: 22, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.inventoryItem.name)
                            .font(.body.weight(.medium))
                            .lineLimit(1)

                        Text(item.room.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let imagePath = item.inspectionItem.image_url {
                        evidenceThumbnail(path: imagePath)
                    }
                }

                Text(primaryStatusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)

                if let resolvedByText {
                    Text(resolvedByText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
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

    private var primaryStatusText: String {
        if effectiveStatus == "resolved", let previousStatus, isResolvableIssue(previousStatus) {
            return String.localizedStringWithFormat(
                NSLocalizedString("pdf.status.resolved_from", comment: ""),
                displayStatus(previousStatus)
            )
        }
        return displayStatus(effectiveStatus)
    }

    private var effectiveStatus: String {
        guard sectionKind == .anomalies else { return status }

        if isResolvableIssue(status) {
            return status
        }
        if let previousStatus, isResolvableIssue(previousStatus) {
            return previousStatus
        }
        return status
    }

    private func isResolvableIssue(_ status: String) -> Bool {
        status == "missing" || status == "damaged"
    }

    private var resolvedByText: String? {
        guard effectiveStatus == "resolved",
              let notes = item.inspectionItem.notes,
              notes.localizedCaseInsensitiveContains("resolved by") else {
            return nil
        }
        return notes.replacingOccurrences(of: "Resolved by ", with: "", options: [.caseInsensitive, .anchored])
    }

    private var rowSymbolName: String {
        switch effectiveStatus {
        case "missing":
            return "questionmark.circle.fill"
        case "damaged":
            return "exclamationmark.triangle.fill"
        case "resolved":
            return "checkmark.circle.fill"
        default:
            return "checkmark.seal.fill"
        }
    }

    @ViewBuilder
    private func evidenceThumbnail(path: String) -> some View {
        InspectionEvidenceAsyncImage(imagePath: path, width: 160) { image in
            Button {
                showFullScreenImage = true
            } label: {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .adaptiveImagePresentation(isPresented: $showFullScreenImage) {
                InspectionEvidenceFullScreenView(imagePath: path)
            }
        } placeholder: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.platformSecondarySystemBackground)
                .frame(width: 56, height: 56)
                .overlay(ProgressView())
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

    @ViewBuilder
    func adaptiveImagePresentation<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
#if os(iOS)
        self.fullScreenCover(isPresented: isPresented, content: content)
#else
        self.sheet(isPresented: isPresented, content: content)
#endif
    }
}
