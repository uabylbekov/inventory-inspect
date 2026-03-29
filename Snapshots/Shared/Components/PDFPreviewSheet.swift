import SwiftUI
import PDFKit

struct PDFPreviewSheet: View {
    let data: Data
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            PDFKitContainer(data: data)
                .navigationTitle(title)
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
#if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button("common.done") {
                            dismiss()
                        }
                    }
#else
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.done") {
                            dismiss()
                        }
                    }
#endif
                    ToolbarItem(placement: .primaryAction) {
                        if let shareURL {
                            ShareLink(item: shareURL) {
                                Label("comparison.share_pdf", systemImage: "square.and.arrow.up")
                            }
                        } else {
                            ProgressView()
                        }
                    }
                }
        }
        .task {
            shareURL = makeTemporaryPDFURL()
        }
        .onDisappear {
            if let url = shareURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func makeTemporaryPDFURL() -> URL? {
        let baseName = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = baseName.isEmpty ? "report" : baseName
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-\(UUID().uuidString)")
            .appendingPathExtension("pdf")

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

#if os(iOS)
private struct PDFKitContainer: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        guard uiView.document == nil else { return }
        uiView.document = PDFDocument(data: data)
    }
}
#else
private struct PDFKitContainer: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        guard nsView.document == nil else { return }
        nsView.document = PDFDocument(data: data)
    }
}
#endif
