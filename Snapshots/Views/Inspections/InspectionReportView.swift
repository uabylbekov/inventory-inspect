import SwiftUI

struct InspectionReportView: View {
    @State private var viewModel: InspectionReportViewModel
    @State private var showingInspectionSelection = false
    @State private var shareablePDF: ShareablePDF?
    
    init(inspection: InspectionModel) {
        _viewModel = State(initialValue: InspectionReportViewModel(inspection: inspection))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                    }
                    
                    List {
                    // MARK: - Header Section
                        // MARK: - Header Section
                        Section {
                            VStack(spacing: 12) {
                                if let prop = viewModel.property {
                                    HStack(alignment: .center) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(prop.name)
                                                .font(.headline)
                                            Text(AppFormatter.formatInspectionType(viewModel.inspection.inspection_type))
                                                .font(.caption.bold())
                                                .foregroundColor(.accentColor)
                                                .textCase(.uppercase)
                                        }
                                        Spacer()
                                        StatusBadge(status: viewModel.inspection.status)
                                    }
                                }
                                
                                Divider()
                                
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("DATE")
                                            .font(.caption2.bold())
                                            .foregroundColor(.secondary)
                                        Text(AppFormatter.formatDate(viewModel.inspection.started_at))
                                            .font(.subheadline.bold())
                                    }
                                    
                                    if let name = viewModel.inspectorName {
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("INSPECTOR")
                                                .font(.caption2.bold())
                                                .foregroundColor(.secondary)
                                            Text(name)
                                                .font(.subheadline.bold())
                                        }
                                    }
                                }
                                
                                if let notes = viewModel.inspection.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 4)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    
                    // MARK: - Anomalies Section
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
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            }
                        } header: {
                            HStack {
                                Text("Anomalies")
                                Spacer()
                                Text("\(viewModel.anomalies.count)")
                            }
                        }
                    } else if !viewModel.resolvedItems.isEmpty {
                        Section {
                            VStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)
                                Text("Inspection Resolved")
                                    .font(.headline)
                                Text("All flagged issues have been fixed.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                        } header: {
                            Text("Anomalies")
                        }
                    } else {
                        Section {
                            VStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.green)
                                Text("Perfect Inspection")
                                    .font(.headline)
                                Text("No missing or damaged items found.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                        } header: {
                            Text("Anomalies")
                        }
                    }
                    
                    // MARK: - Resolved Section
                    if !viewModel.resolvedItems.isEmpty {
                        Section {
                            ForEach(viewModel.resolvedItems) { item in
                                ReportItemRow(item: item)
                                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            }
                        } header: {
                            HStack {
                                Text("Resolved Issues")
                                Spacer()
                                Text("\(viewModel.resolvedItems.count)")
                            }
                        }
                    }
                    
                    // MARK: - Present Items Section
                    if !viewModel.presentItems.isEmpty {
                        Section {
                            ForEach(viewModel.presentItems) { item in
                                ReportItemRow(item: item)
                                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            }
                        } header: {
                            HStack {
                                Text("Present & Intact")
                                Spacer()
                                Text("\(viewModel.presentItems.count)")
                            }
                        }
                    }
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
        .animation(.default, value: viewModel.isLoading)
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isGeneratingPDF {
                    ProgressView()
                } else {
                    Button(action: {
                        if let data = viewModel.generatePDF() {
                            let filename = "Report_\(viewModel.property?.name ?? "Inspection").pdf"
                            self.shareablePDF = ShareablePDF(data: data, filename: filename)
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .imageScale(.large)
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingInspectionSelection = true }) {
                    Image(systemName: "camera.viewfinder")
                        .imageScale(.large)
                }
            }
        }
        .sheet(item: $shareablePDF) { pdf in
            ShareSheet(data: pdf.data, filename: pdf.filename)
        }
        .sheet(isPresented: $showingInspectionSelection) {
            CompareSelectSheet(currentInspection: viewModel.inspection)
        }
        .task {
            await viewModel.fetchReportData()
        }
        .refreshable {
            await viewModel.fetchReportData()
        }
    }
}

// MARK: - PDF Share Helpers

struct ShareablePDF: Identifiable {
    let id = UUID()
    let data: Data
    let filename: String
}

struct ShareSheet: UIViewControllerRepresentable {
    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)
        let vc = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Report Item Row

struct ReportItemRow: View {
    let item: ReportItem
    var onResolve: (() -> Void)? = nil
    @State private var showFullScreenImage = false
    @State private var showingResolveConfirmation = false
    
    private var status: String { item.inspectionItem.status }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.inventoryItem.name)
                            .lineLimit(1)
                        
                        Text(item.room.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: StatusUI.icon(for: status))
                        .foregroundColor(StatusUI.color(for: status))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    StatusBadge(status: status)
                }
            }
            
            if let notes = item.inspectionItem.notes, !notes.isEmpty {
                Label(notes, systemImage: "note.text")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 32 + 12)
            }
            
            if let imgStr = item.inspectionItem.image_url, let url = URL(string: imgStr) {
                CachedAsyncImage(url: url, width: 600) { image in
                    Button { showFullScreenImage = true } label: {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .fullScreenCover(isPresented: $showFullScreenImage) {
                        FullScreenImageView(image: .remote(url))
                    }
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(height: 200)
                        .overlay(ProgressView())
                }
                .padding(.leading, 32 + 12)
            }
            
            if let onResolve = onResolve, (status == "damaged" || status == "missing") {
                Button(action: { showingResolveConfirmation = true }) {
                    HStack {
                        Spacer()
                        Text("Resolve Issue")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 4)
                .alert("Resolve This Issue?", isPresented: $showingResolveConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Mark as Resolved") { onResolve() }
                } message: {
                    Text("This will mark the issue as resolved. This action cannot be undone.")
                }
            }
        }
        .padding(.vertical, 8)
    }
}
