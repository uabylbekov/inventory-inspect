import Foundation
import SwiftUI

struct GeneratedPDF {
    let data: Data
    let filename: String
}

enum InspectionExportService {
    private struct BrandingDetails {
        let logoImage: PlatformImage?
        let isWhiteLabel: Bool
        let businessDetailsLines: [String]
    }

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
        let pdfData = await renderInspectionReportPDF(
            inspection: inspection,
            property: property,
            inspectorName: inspectorName,
            anomalies: anomalies,
            resolvedItems: resolvedItems,
            presentItems: presentItems,
            branding: branding
        )

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
        let data = await MainActor.run {
            PDFReportGenerator.generateComparison(
                older: older,
                newer: newer,
                property: property,
                inspectorName: inspectorName,
                changedItems: changedItems,
                unchangedItems: unchangedItems,
                logoImage: branding.logoImage,
                isWhiteLabel: branding.isWhiteLabel,
                businessDetailsLines: branding.businessDetailsLines
            )
        }

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

    @MainActor
    private static func renderInspectionReportPDF(
        inspection: InspectionModel,
        property: PropertyModel,
        inspectorName: String?,
        anomalies: [ReportItem],
        resolvedItems: [ReportItem],
        presentItems: [ReportItem],
        branding: BrandingDetails
    ) async -> NSMutableData {
        let pdfView = InspectionPDFView(
            property: property,
            inspection: inspection,
            inspectorName: inspectorName,
            anomalies: anomalies,
            resolvedItems: resolvedItems,
            presentItems: presentItems,
            logoImage: branding.logoImage,
            isWhiteLabel: branding.isWhiteLabel,
            businessDetailsLines: branding.businessDetailsLines
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

        return pdfData
    }

    private static func loadBranding(for property: PropertyModel?) async -> BrandingDetails {
        let accessManager = SnapshotsAccessManager.shared
        let hasPro = accessManager.isPro(for: property)
        let isWhiteLabel = accessManager.isBusiness(for: property)
        let businessDetailsLines = isWhiteLabel ? parseBusinessDetails(from: property?.owner?.business_details) : []

        guard hasPro,
              let logoUrlString = property?.owner?.company_logo_url,
              let logoURL = URL(string: logoUrlString),
              let (data, _) = try? await URLSession.shared.data(from: logoURL) else {
            return BrandingDetails(
                logoImage: nil,
                isWhiteLabel: isWhiteLabel,
                businessDetailsLines: businessDetailsLines
            )
        }

        return BrandingDetails(
            logoImage: makePlatformImage(from: data),
            isWhiteLabel: isWhiteLabel,
            businessDetailsLines: businessDetailsLines
        )
    }

    private static func parseBusinessDetails(from rawValue: String?) -> [String] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let details = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return []
        }

        return [
            details["business_name"],
            details["business_address"],
            details["business_phone"],
            details["business_website"]
        ]
        .compactMap { value in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
    }
}
