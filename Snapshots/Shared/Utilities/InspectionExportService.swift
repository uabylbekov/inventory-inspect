import Foundation
import SwiftUI
import UIKit

struct GeneratedPDF {
    let data: Data
    let filename: String
}

enum InspectionExportService {
    static func makeInspectionReportPDF(
        inspection: InspectionModel,
        property: PropertyModel?,
        inspectorName: String?,
        anomalies: [ReportItem],
        resolvedItems: [ReportItem],
        presentItems: [ReportItem]
    ) async -> GeneratedPDF? {
        guard let property else { return nil }

        let branding = await loadBranding(for: property)
        let pdfView = InspectionPDFView(
            property: property,
            inspection: inspection,
            inspectorName: inspectorName,
            anomalies: anomalies,
            resolvedItems: resolvedItems,
            presentItems: presentItems,
            logoImage: branding.logoImage,
            isWhiteLabel: branding.isWhiteLabel
        )
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: pdfView)
        renderer.scale = 1
        let pdfData = NSMutableData()
        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: size)

            guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
                  let pdfContext = CGContext(consumer: consumer, mediaBox: &box, nil)
            else { return }

            pdfContext.beginPDFPage(nil)
            context(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
        }

        guard pdfData.length > 0 else { return nil }

        let filename = ExportFileNameBuilder.pdfFileName(
            prefix: "Report",
            parts: [
                property.name,
                AppFormatter.formatInspectionType(inspection.inspection_type),
                AppFormatter.formatDate(inspection.started_at)
            ]
        )

        return GeneratedPDF(data: pdfData as Data, filename: filename)
    }

    static func makeComparisonReportPDF(
        older: InspectionModel,
        newer: InspectionModel,
        property: PropertyModel?,
        inspectorName: String?,
        changedItems: [DiffItem],
        unchangedItems: [DiffItem]
    ) async -> GeneratedPDF {
        let branding = await loadBranding(for: property)
        let data = PDFReportGenerator.generateComparison(
            older: older,
            newer: newer,
            property: property,
            inspectorName: inspectorName,
            changedItems: changedItems,
            unchangedItems: unchangedItems,
            logoImage: branding.logoImage,
            isWhiteLabel: branding.isWhiteLabel
        )

        let filename = ExportFileNameBuilder.pdfFileName(
            prefix: "ComparisonReport",
            parts: [
                property?.name ?? "Inspection",
                AppFormatter.formatDate(older.completed_at ?? older.started_at),
                AppFormatter.formatDate(newer.completed_at ?? newer.started_at)
            ]
        )

        return GeneratedPDF(data: data, filename: filename)
    }

    private static func loadBranding(for property: PropertyModel?) async -> (logoImage: UIImage?, isWhiteLabel: Bool) {
        let accessManager = SnapshotsAccessManager.shared
        let hasPro = accessManager.isPro(for: property)
        let isWhiteLabel = accessManager.isEnterprise(for: property)

        guard hasPro,
              let logoUrlString = property?.owner?.company_logo_url,
              let logoURL = URL(string: logoUrlString),
              let (data, _) = try? await URLSession.shared.data(from: logoURL) else {
            return (nil, isWhiteLabel)
        }

        return (UIImage(data: data), isWhiteLabel)
    }
}
