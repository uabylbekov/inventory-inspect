import SwiftUI
import UniformTypeIdentifiers

struct InspectionReportView: View {
    @State private var viewModel: InspectionReportViewModel
    @State private var showingInspectionSelection = false
    @State private var exportDocument: ExportedPDFDocument?
    @State private var exportFilename = ""
    @State private var showingExporter = false
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
                    LabeledContent("Property", value: prop.name)
                    LabeledContent("Address", value: prop.address_line1 ?? String(localized: "property.no_address"))
                }
                LabeledContent("Type", value: AppFormatter.formatInspectionType(viewModel.inspection.inspection_type))
                LabeledContent("report.date", value: AppFormatter.formatDate(viewModel.inspection.started_at))
                if let name = viewModel.inspectorName {
                    LabeledContent("report.inspector", value: name)
                }
            }
            .redacted(reason: viewModel.isLoading ? .placeholder : [])

            if !viewModel.isLoading {
                Section {
                    LabeledContent("report.anomalies", value: "\(viewModel.anomalies.count)")
                    LabeledContent("report.resolved_issues", value: "\(viewModel.resolvedItems.count)")
                    LabeledContent("report.present_intact", value: "\(viewModel.presentItems.count)")
                }
            }

            if !viewModel.anomalies.isEmpty {
                Section {
                    ForEach(viewModel.anomalies) { item in
                        ReportItemRow(item: item, onResolve: {
                            Task { 
                                HapticManager.shared.impact(style: .medium)
                                await viewModel.resolveAnomaly(reportItem: item) 
                                HapticManager.shared.notification(type: .success)
                            }
                        })
                    }
                } header: {
                    HStack {
                        Text("report.anomalies")
                        Spacer()
                        Text("\(viewModel.anomalies.count)")
                    }
                }
            } else if !viewModel.isLoading && !viewModel.resolvedItems.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("report.resolved_title")
                        Text("report.resolved_subtitle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("report.anomalies")
                }
            } else if !viewModel.isLoading {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("report.perfect_title")
                        Text("report.perfect_subtitle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("report.anomalies")
                }
            }
            
            if !viewModel.resolvedItems.isEmpty {
                Section {
                    ForEach(viewModel.resolvedItems) { item in
                        ReportItemRow(item: item)
                    }
                } header: {
                    HStack {
                        Text("report.resolved_issues")
                        Spacer()
                        Text("\(viewModel.resolvedItems.count)")
                    }
                }
            }
            
            if !viewModel.presentItems.isEmpty {
                Section {
                    ForEach(viewModel.presentItems) { item in
                        ReportItemRow(item: item)
                    }
                } header: {
                    HStack {
                        Text("report.present_intact")
                        Spacer()
                        Text("\(viewModel.presentItems.count)")
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.platformGroupedBackground
                        .ignoresSafeArea()
                    ProgressView("report.loading")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                                exportDocument = ExportedPDFDocument(data: pdf.data)
                                exportFilename = pdf.filename
                                showingExporter = true
                            }
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .imageScale(.large)
                    }
                }
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
        .sheet(isPresented: $showingInspectionSelection) {
            CompareSelectSheet(currentInspection: viewModel.inspection)
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .task {
            await viewModel.fetchReportData()
        }
        .refreshable {
            await viewModel.fetchReportData(showLoadingState: false)
        }
    }
}

// MARK: - Report Item Row

struct ReportItemRow: View {
    let item: ReportItem
    var onResolve: (() -> Void)? = nil
    @State private var showFullScreenImage = false
    @State private var showingResolveConfirmation = false
    
    private var status: String { item.inspectionItem.status }
    private var previousStatus: String? { item.inspectionItem.previous_status }
    
    private var statusColor: Color {
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.inventoryItem.name)
                .lineLimit(1)
            Text(item.room.name)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(primaryStatusText)
                .font(.caption)
                .foregroundColor(statusColor)
            
            if let notes = item.inspectionItem.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let imgStr = item.inspectionItem.image_url, let url = URL(string: imgStr) {
                CachedAsyncImage(url: url, width: 600) { image in
                    Button { showFullScreenImage = true } label: {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .adaptiveImagePresentation(isPresented: $showFullScreenImage) {
                        FullScreenImageView(image: .remote(url))
                    }
                } placeholder: {
                    Rectangle()
                        .fill(Color.platformSecondarySystemBackground)
                        .frame(height: 200)
                        .overlay(ProgressView())
                }
                .padding(.leading, 32 + 12)
            }
            
            if let onResolve = onResolve, (status == "damaged" || status == "missing") {
                Button(action: { showingResolveConfirmation = true }) {
                    Label("report.resolve_issue", systemImage: "checkmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .alert("report.resolve_title", isPresented: $showingResolveConfirmation) {
                    Button("common.cancel", role: .cancel) {}
                    Button("report.mark_resolved") { onResolve() }
                } message: {
                    Text("report.resolve_message")
                }
            }
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

    private var primaryStatusText: String {
        if status == "resolved", let previousStatus, isResolvableIssue(previousStatus) {
            return "Resolved from \(displayStatus(previousStatus))"
        }
        return displayStatus(status)
    }

    private func isResolvableIssue(_ status: String) -> Bool {
        status == "missing" || status == "damaged"
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
