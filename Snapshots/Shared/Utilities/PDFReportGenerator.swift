import SwiftUI

struct PDFReportGenerator {
    static func generate(
        inspection: InspectionModel,
        property: PropertyModel?,
        inspectorName: String?,
        anomalies: [ReportItem],
        presentItems: [ReportItem] = [],
        resolvedItems: [ReportItem] = [],
        logoImage: PlatformImage? = nil,
        isWhiteLabel: Bool = false,
        businessDetailsLines: [String] = []
    ) -> Data {
        guard let property else { return Data() }

        let view = InspectionPDFView(
            property: property,
            inspection: inspection,
            inspectorName: inspectorName,
            anomalies: anomalies,
            resolvedItems: resolvedItems,
            presentItems: presentItems,
            logoImage: logoImage,
            isWhiteLabel: isWhiteLabel,
            businessDetailsLines: businessDetailsLines
        )

        return renderPDF(from: view)
    }

    static func generateComparison(
        older: InspectionModel,
        newer: InspectionModel,
        property: PropertyModel?,
        inspectorName: String?,
        changedItems: [DiffItem],
        unchangedItems: [DiffItem],
        logoImage: PlatformImage? = nil,
        isWhiteLabel: Bool = false,
        businessDetailsLines: [String] = []
    ) -> Data {
        let view = ComparisonPDFDocumentView(
            older: older,
            newer: newer,
            property: property,
            inspectorName: inspectorName,
            changedItems: changedItems,
            unchangedItems: unchangedItems,
            logoImage: logoImage,
            isWhiteLabel: isWhiteLabel,
            businessDetailsLines: businessDetailsLines
        )

        return renderPDF(from: view)
    }

    private static func renderPDF<Content: View>(from view: Content) -> Data {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = 1
        let pdfData = NSMutableData()
        let pageHeight: CGFloat = 792

        renderer.render { size, context in
            let pageRect = CGRect(origin: .zero, size: CGSize(width: size.width, height: pageHeight))
            var mediaBox = pageRect
            let pageCount = max(Int(ceil(size.height / pageHeight)), 1)

            guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
                  let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
            else { return }

            for pageIndex in 0..<pageCount {
                pdfContext.beginPDFPage(nil)
                pdfContext.saveGState()
                pdfContext.translateBy(x: 0, y: -CGFloat(pageIndex) * pageHeight)
                context(pdfContext)
                pdfContext.restoreGState()
                pdfContext.endPDFPage()
            }

            pdfContext.closePDF()
        }

        return pdfData as Data
    }
}

private struct ComparisonPDFDocumentView: View {
    let older: InspectionModel
    let newer: InspectionModel
    let property: PropertyModel?
    let inspectorName: String?
    let changedItems: [DiffItem]
    let unchangedItems: [DiffItem]
    let logoImage: PlatformImage?
    let isWhiteLabel: Bool
    let businessDetailsLines: [String]

    private let canvas = Color.white
    private let panel = Color(red: 0.96, green: 0.97, blue: 0.985)
    private let border = Color(red: 0.88, green: 0.90, blue: 0.94)
    private let primaryText = Color.black
    private let secondaryText = Color(red: 0.34, green: 0.38, blue: 0.45)
    private let accent = Color(red: 0.11, green: 0.34, blue: 0.87)

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header
            summary

            if !changedItems.isEmpty {
                sectionBlock(
                    title: "Changed Items",
                    subtitle: "\(changedItems.count) updates detected",
                    items: changedItems
                )
            }

            if !unchangedItems.isEmpty {
                sectionBlock(
                    title: "Unchanged Items",
                    subtitle: "\(unchangedItems.count) items stayed the same",
                    items: unchangedItems
                )
            }

            footer
        }
        .padding(36)
        .frame(width: 612, alignment: .topLeading)
        .background(canvas)
        .foregroundColor(primaryText)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("COMPARISON REPORT")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accent)
                        .tracking(0.8)

                    Text(property?.name ?? "Inspection Comparison")
                        .font(.system(size: 28, weight: .bold))

                    Text(property?.address_line1 ?? String(localized: "pdf.address_missing"))
                        .font(.system(size: 14))
                        .foregroundColor(secondaryText)
                }

                Spacer()

                if let logoImage {
                    Image(platformImage: logoImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                }
            }

            if isWhiteLabel, !businessDetailsLines.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(businessDetailsLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11))
                            .foregroundColor(secondaryText)
                    }
                }
            }

            HStack(spacing: 12) {
                metaCard(label: "Previous", value: "\(AppFormatter.formatInspectionType(older.inspection_type)) • \(AppFormatter.formatDate(older.completed_at ?? older.started_at))")
                metaCard(label: "Current", value: "\(AppFormatter.formatInspectionType(newer.inspection_type)) • \(AppFormatter.formatDate(newer.completed_at ?? newer.started_at))")
                metaCard(label: "Inspector", value: inspectorName ?? String(localized: "common.unknown"))
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            summaryCard(title: "Changed", count: changedItems.count, color: .red)
            summaryCard(title: "Unchanged", count: unchangedItems.count, color: .green)
        }
    }

    private var footer: some View {
        Text(isWhiteLabel ? "Generated on \(AppFormatter.formatDate(newer.started_at))" : "Generated by Snapshots")
            .font(.system(size: 11))
            .foregroundColor(secondaryText)
    }

    private func metaCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(secondaryText)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func summaryCard(title: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 24, height: 24)
                .overlay(Circle().fill(color).frame(width: 8, height: 8))

            Text("\(count)")
                .font(.system(size: 24, weight: .bold))

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func sectionBlock(title: String, subtitle: String, items: [DiffItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(secondaryText)
            }

            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.itemName)
                        .font(.system(size: 14, weight: .semibold))
                    Text(item.roomName)
                        .font(.system(size: 12))
                        .foregroundColor(secondaryText)
                    Text("Previous: \(item.oldStatus.capitalized)")
                        .font(.system(size: 12))
                    Text("Current: \(item.newStatus.capitalized)")
                        .font(.system(size: 12))
                    if let notes = item.newNotes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundColor(secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
