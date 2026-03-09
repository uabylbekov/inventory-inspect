import SwiftUI
import Supabase

struct ComparisonReportView: View {
    @State private var viewModel: ComparisonReportViewModel
    @State private var isGeneratingPDF = false
    @State private var pdfShareItem: ShareablePDF?
    @State private var showingPaywall = false
    private let accessManager = SnapshotsAccessManager.shared
    
    init(base: InspectionModel, current: InspectionModel) {
        _viewModel = State(initialValue: ComparisonReportViewModel(base: base, current: current))
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            // Header
            Section {
                HStack(alignment: .center, spacing: 12) {
                    // Left Side (Older)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppFormatter.formatInspectionType(viewModel.older.inspection_type).uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Text(AppFormatter.formatDate(viewModel.older.completed_at ?? viewModel.older.started_at))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                    
                    // Right Side (Newer)
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(AppFormatter.formatInspectionType(viewModel.newer.inspection_type).uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        
                        Text(AppFormatter.formatDate(viewModel.newer.completed_at ?? viewModel.newer.started_at))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
            .redacted(reason: viewModel.isLoading ? .placeholder : [])
            
            if let error = viewModel.errorMessage {
                Section {
                    VStack(spacing: 12) {
                        Text("Comparison Failed")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            Task { await viewModel.fetchComparison() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else if !viewModel.isLoading && viewModel.changedItems.isEmpty && viewModel.unchangedItems.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No Shared Data")
                            .font(.headline)
                        Text("No items overlap between these inspections.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                // Changes Section
                if !viewModel.changedItems.isEmpty {
                    Section {
                        ForEach(viewModel.changedItems) { diff in
                            DiffRowView(diff: diff)
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        }
                    } header: {
                        Text("\(viewModel.changedItems.count) Changes Found")
                            .foregroundColor(.red)
                    }
                }
                
                // Unchanged Section
                if !viewModel.unchangedItems.isEmpty {
                    Section {
                        ForEach(viewModel.unchangedItems) { diff in
                            DiffRowView(diff: diff)
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        }
                    } header: {
                        Text("\(viewModel.unchangedItems.count) Unchanged Items")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()
                    ProgressView("Analyzing Differences…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .animation(.none, value: viewModel.isLoading)
        .navigationTitle("Inspection Comparison")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isGeneratingPDF = true
                    Task {
                        let data = PDFReportGenerator.generate(
                            inspection: viewModel.newer,
                            property: viewModel.property,
                            inspectorName: viewModel.inspectorName,
                            anomalies: viewModel.anomalies,
                            presentItems: viewModel.presentItems
                        )
                        pdfShareItem = ShareablePDF(data: data, filename: "ComparisonReport.pdf")
                        isGeneratingPDF = false
                    }
                } label: {
                    if isGeneratingPDF {
                        ProgressView()
                    } else {
                        HStack(spacing: 4) {
                            if !accessManager.isPro {
                                Text("PRO")
                                    .font(.system(size: 8, weight: .black))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .disabled(viewModel.isLoading || isGeneratingPDF)
            }
        }
        .sheet(item: $pdfShareItem) { pdf in
            ShareSheet(data: pdf.data, filename: "InspectionReport.pdf")
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
        
        private var hasChanged: Bool { diff.oldStatus != diff.newStatus }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Context header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(diff.itemName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(diff.roomName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                }
                
                // Diff Side by Side Box
                HStack(alignment: .top, spacing: 0) {
                    // Previous
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PREVIOUS")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        StatusBadge(status: diff.oldStatus)
                        
                        if let oldImg = diff.oldImage, let url = URL(string: oldImg) {
                            CachedAsyncImage(url: url, width: 300) { image in
                                Button { showOldImage = true } label: {
                                    image.resizable().scaledToFill().frame(height: 90).clipped().cornerRadius(8)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .fullScreenCover(isPresented: $showOldImage) {
                                    FullScreenImageView(image: .remote(url))
                                }
                            } placeholder: {
                                Color(UIColor.systemGray5).frame(height: 90).cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    
                    Divider()
                    
                    // Current
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CURRENT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        StatusBadge(status: diff.newStatus)
                        
                        if let newImg = diff.newImage, let url = URL(string: newImg) {
                            CachedAsyncImage(url: url, width: 300) { image in
                                Button { showNewImage = true } label: {
                                    image.resizable().scaledToFill().frame(height: 90).clipped().cornerRadius(8)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .fullScreenCover(isPresented: $showNewImage) {
                                    FullScreenImageView(image: .remote(url))
                                }
                            } placeholder: {
                                Color(UIColor.systemGray5).frame(height: 90).cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(UIColor.separator), lineWidth: 0.5)
                )
                
                // Highlight notes if new ones exist
                if let newNotes = diff.newNotes, !newNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Notes")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(newNotes)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }
}
