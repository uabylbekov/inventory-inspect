import Foundation

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
        // PDF rendering only shows photos for missing/damaged items.
        // Avoid loading images that will never be drawn.
        let evidenceImages = await loadEvidenceImages(from: anomalies)
        let pdfData = PDFReportGenerator.generate(
            inspection: inspection,
            property: property,
            inspectorName: inspectorName,
            anomalies: anomalies,
            presentItems: presentItems,
            resolvedItems: resolvedItems,
            evidenceImages: evidenceImages,
            logoImage: branding.logoImage,
            isWhiteLabel: branding.isWhiteLabel,
            businessDetailsLines: branding.businessDetailsLines
        )

        guard !pdfData.isEmpty else { return nil }

        let filename = ExportFileNameBuilder.pdfFileName(
            prefix: "Report",
            parts: [
                property.name,
                AppFormatter.formatInspectionType(inspection.inspection_type),
                AppFormatter.formatDate(inspection.started_at)
            ]
        )

        return GeneratedPDF(data: pdfData, filename: filename)
    }

    static func makeComparisonReportPDF(
        older: InspectionModel,
        newer: InspectionModel,
        property: PropertyModel?,
        previousInspectorName: String?,
        currentInspectorName: String?,
        changedItems: [DiffItem],
        unchangedItems: [DiffItem]
    ) async -> GeneratedPDF {
        let comparisonEvidenceImages = await loadComparisonEvidenceImages(
            from: changedItems + unchangedItems
        )
        let branding = await loadBranding(for: property)
        let data = PDFReportGenerator.generateComparison(
            older: older,
            newer: newer,
            property: property,
            previousInspectorName: previousInspectorName,
            currentInspectorName: currentInspectorName,
            changedItems: changedItems,
            unchangedItems: unchangedItems,
            evidenceImages: comparisonEvidenceImages,
            logoImage: branding.logoImage,
            isWhiteLabel: branding.isWhiteLabel,
            businessDetailsLines: branding.businessDetailsLines
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

    private static func loadEvidenceImages(from items: [ReportItem]) async -> [UUID: PlatformImage] {
        await withTaskGroup(of: (UUID, PlatformImage)?.self) { group in
            for item in items {
                guard let rawImagePath = InspectionImageStorage.normalizePath(item.inspectionItem.image_url) else {
                    continue
                }

                let itemId = item.inspectionItem.id

                group.addTask {
                    guard let resolvedURL = await resolveEvidenceURL(from: rawImagePath) else { return nil }
                    if let cached = ImageCache.shared.get(for: resolvedURL) {
                        return (itemId, cached)
                    }
                    guard let (data, _) = try? await URLSession.shared.data(from: resolvedURL),
                          let image = makePlatformImage(from: data) else {
                        return nil
                    }
                    ImageCache.shared.set(image, for: resolvedURL)
                    return (itemId, image)
                }
            }

            var evidenceByItemId: [UUID: PlatformImage] = [:]
            for await loadedImage in group {
                guard let (itemId, image) = loadedImage else { continue }
                evidenceByItemId[itemId] = image
            }
            return evidenceByItemId
        }
    }

    private static func resolveEvidenceURL(from imagePath: String) async -> URL? {
        if imagePath.contains("://"), let absoluteURL = URL(string: imagePath) {
            return transformedEvidenceURL(from: absoluteURL)
        }

        // Most inspection evidence is stored as a bucket-relative path.
        // Use signed URLs so PDF exports can access private objects reliably.
        return try? await InspectionImageStorage.signedURL(for: imagePath, width: 900, height: 600)
    }

    private static func transformedEvidenceURL(from url: URL) -> URL {
        guard url.absoluteString.contains("/storage/v1/object/public/") else { return url }

        let transformed = url.absoluteString.replacingOccurrences(
            of: "/storage/v1/object/public/",
            with: "/storage/v1/render/image/public/"
        )
        var components = URLComponents(string: transformed)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "width", value: "900"))
        queryItems.append(URLQueryItem(name: "height", value: "600"))
        queryItems.append(URLQueryItem(name: "quality", value: "85"))
        queryItems.append(URLQueryItem(name: "resize", value: "contain"))
        components?.queryItems = queryItems
        return components?.url ?? url
    }

    private static func loadComparisonEvidenceImages(from diffs: [DiffItem]) async -> [String: PlatformImage] {
        // Comparison PDF only shows photos if either side is missing/damaged.
        let paths = Set(diffs.flatMap { diff -> [String] in
            guard shouldRenderComparisonPhotos(oldStatus: diff.oldStatus, newStatus: diff.newStatus) else {
                return []
            }
            return [InspectionImageStorage.normalizePath(diff.oldImage), InspectionImageStorage.normalizePath(diff.newImage)]
                .compactMap { $0 }
        })

        return await withTaskGroup(of: (String, PlatformImage)?.self) { group in
            for path in paths {
                group.addTask {
                    guard let resolvedURL = await resolveEvidenceURL(from: path) else { return nil }
                    if let cached = ImageCache.shared.get(for: resolvedURL) {
                        return (path, cached)
                    }
                    guard let (data, _) = try? await URLSession.shared.data(from: resolvedURL),
                          let image = makePlatformImage(from: data) else {
                        return nil
                    }
                    ImageCache.shared.set(image, for: resolvedURL)
                    return (path, image)
                }
            }

            var imageMap: [String: PlatformImage] = [:]
            for await loaded in group {
                guard let (path, image) = loaded else { continue }
                imageMap[path] = image
            }
            return imageMap
        }
    }

    private static func shouldRenderComparisonPhotos(oldStatus: String, newStatus: String) -> Bool {
        isIssueStatus(oldStatus) || isIssueStatus(newStatus)
    }

    private static func isIssueStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized == "missing" || normalized == "damaged"
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
