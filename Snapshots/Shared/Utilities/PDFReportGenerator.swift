import Foundation

#if canImport(UIKit)
import UIKit

struct PDFReportGenerator {
    static func generate(
        inspection: InspectionModel,
        property: PropertyModel?,
        inspectorName: String?,
        anomalies: [ReportItem],
        presentItems: [ReportItem] = [],
        resolvedItems: [ReportItem] = [],
        evidenceImages: [UUID: PlatformImage] = [:],
        logoImage: PlatformImage? = nil,
        isWhiteLabel: Bool = false,
        businessDetailsLines: [String] = []
    ) -> Data {
        guard let property else { return Data() }

        let painter = PDFPainter()
        return painter.render { p in
            let sectionGap: CGFloat = 12
            p.drawInspectionHeader(
                title: String(localized: "pdf.report.title"),
                propertyName: property.name,
                address: property.address_line1 ?? String(localized: "pdf.address_missing"),
                inspectionType: AppFormatter.formatInspectionType(inspection.inspection_type),
                date: AppFormatter.formatDate(inspection.started_at),
                inspectorName: inspectorName ?? String(localized: "common.unknown"),
                status: inspection.status.replacingOccurrences(of: "_", with: " ").capitalized,
                logoImage: logoImage,
                businessDetailsLines: isWhiteLabel ? businessDetailsLines : []
            )

            p.drawInspectionTotals(
                anomalies: anomalies.count,
                resolved: resolvedItems.count,
                present: presentItems.count
            )
            p.cursorY += 12

            if let notes = inspection.notes, !notes.isEmpty {
                p.drawSectionHeader(
                    title: String(localized: "pdf.meta.notes"),
                    subtitle: nil
                )
                p.drawBodyText(notes)
                p.cursorY += sectionGap
            }

            if !anomalies.isEmpty {
                p.drawInspectionSection(
                    title: String(localized: "pdf.section.anomalies"),
                    subtitle: "\(anomalies.count) items require attention",
                    items: anomalies,
                    evidenceImages: evidenceImages
                )
            }

            if !resolvedItems.isEmpty {
                p.drawInspectionSection(
                    title: String(localized: "pdf.section.resolved"),
                    subtitle: "\(resolvedItems.count) issues were fixed",
                    items: resolvedItems,
                    evidenceImages: evidenceImages
                )
            }

            if !presentItems.isEmpty {
                p.drawInspectionSection(
                    title: String(localized: "report.present_intact"),
                    subtitle: "\(presentItems.count) items were present and intact",
                    items: presentItems,
                    evidenceImages: evidenceImages
                )
            }

            let footerDate = AppFormatter.formatDate(inspection.completed_at ?? inspection.started_at)
            let footerText: String = isWhiteLabel
            ? String.localizedStringWithFormat(
                NSLocalizedString("comparison_pdf.generated_on", comment: ""),
                footerDate
            )
            : String.localizedStringWithFormat(
                NSLocalizedString("pdf.footer_with_date", comment: ""),
                footerDate
            )
            p.drawFooter(footerText)
        }
    }

    static func generateComparison(
        older: InspectionModel,
        newer: InspectionModel,
        property: PropertyModel?,
        previousInspectorName: String?,
        currentInspectorName: String?,
        changedItems: [DiffItem],
        unchangedItems: [DiffItem],
        evidenceImages: [String: PlatformImage] = [:],
        logoImage: PlatformImage? = nil,
        isWhiteLabel: Bool = false,
        businessDetailsLines: [String] = []
    ) -> Data {
        let painter = PDFPainter()
        return painter.render { p in
            let unknownInspector = String(localized: "common.unknown")
            let previousInspectorValue = previousInspectorName ?? unknownInspector
            let currentInspectorValue = currentInspectorName ?? unknownInspector
            p.drawComparisonHeader(
                title: String(localized: "comparison_pdf.title"),
                propertyName: property?.name ?? String(localized: "comparison.title"),
                address: property?.address_line1 ?? String(localized: "pdf.address_missing"),
                previous: "\(AppFormatter.formatInspectionType(older.inspection_type)) • \(AppFormatter.formatDate(older.completed_at ?? older.started_at))\n\(String(localized: "pdf.meta.inspector")): \(previousInspectorValue)",
                current: "\(AppFormatter.formatInspectionType(newer.inspection_type)) • \(AppFormatter.formatDate(newer.completed_at ?? newer.started_at))\n\(String(localized: "pdf.meta.inspector")): \(currentInspectorValue)",
                logoImage: logoImage,
                businessDetailsLines: isWhiteLabel ? businessDetailsLines : []
            )

            p.drawComparisonTotals(changed: changedItems.count, unchanged: unchangedItems.count)
            p.cursorY += 12

            if !changedItems.isEmpty {
                p.drawComparisonSection(
                    title: String(localized: "comparison_pdf.changed_items"),
                    subtitle: String.localizedStringWithFormat(
                        NSLocalizedString("comparison_pdf.changed_items_subtitle", comment: ""),
                        changedItems.count
                    ),
                    items: changedItems,
                    evidenceImages: evidenceImages
                )
            }

            if !unchangedItems.isEmpty {
                p.drawComparisonSection(
                    title: String(localized: "comparison_pdf.unchanged_items"),
                    subtitle: String.localizedStringWithFormat(
                        NSLocalizedString("comparison_pdf.unchanged_items_subtitle", comment: ""),
                        unchangedItems.count
                    ),
                    items: unchangedItems,
                    evidenceImages: evidenceImages
                )
            }

            let footerText: String = isWhiteLabel
            ? String.localizedStringWithFormat(
                NSLocalizedString("comparison_pdf.generated_on", comment: ""),
                AppFormatter.formatDate(newer.started_at)
            )
            : String(localized: "comparison_pdf.generated_by")
            p.drawFooter(footerText)
        }
    }
}

private final class PDFPainter {
    struct Style {
        let font: UIFont
        let color: UIColor
    }

    private let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    private let margin: CGFloat = 34
    private let dividerColor = UIColor(red: 0.90, green: 0.91, blue: 0.93, alpha: 1)
    private let primaryColor = UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1)
    private let secondaryColor = UIColor(red: 0.34, green: 0.37, blue: 0.43, alpha: 1)

    private lazy var titleStyle = Style(
        font: UIFont(name: "TimesNewRomanPS-BoldMT", size: 29) ?? .boldSystemFont(ofSize: 29),
        color: primaryColor
    )
    private lazy var sectionTitleStyle = Style(
        font: UIFont(name: "TimesNewRomanPS-BoldMT", size: 18) ?? .boldSystemFont(ofSize: 18),
        color: primaryColor
    )
    private lazy var labelStyle = Style(
        font: UIFont.systemFont(ofSize: 9, weight: .semibold),
        color: secondaryColor
    )
    private lazy var bodyStyle = Style(
        font: UIFont.systemFont(ofSize: 11.5, weight: .regular),
        color: primaryColor
    )
    private lazy var valueStyle = Style(
        font: UIFont.systemFont(ofSize: 12.5, weight: .medium),
        color: primaryColor
    )
    private lazy var itemTitleStyle = Style(
        font: UIFont.systemFont(ofSize: 13.5, weight: .semibold),
        color: primaryColor
    )
    private lazy var smallStyle = Style(
        font: UIFont.systemFont(ofSize: 9.5, weight: .regular),
        color: secondaryColor
    )

    private var context: UIGraphicsPDFRendererContext?
    var cursorY: CGFloat = 34

    private var contentWidth: CGFloat { pageRect.width - (margin * 2) }
    private var contentBottom: CGFloat { pageRect.height - margin }
    private var detailColumnWidth: CGFloat { contentWidth * 0.54 }
    private var photoColumnWidth: CGFloat { contentWidth - detailColumnWidth - 14 }

    func render(_ draw: (PDFPainter) -> Void) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { rendererContext in
            context = rendererContext
            beginPage()
            draw(self)
        }
    }

    private func beginPage() {
        context?.beginPage()
        cursorY = margin
    }

    private func ensureSpace(_ estimatedHeight: CGFloat) {
        if cursorY + estimatedHeight <= contentBottom { return }
        beginPage()
    }

    func drawInspectionHeader(
        title: String,
        propertyName: String,
        address: String,
        inspectionType: String,
        date: String,
        inspectorName: String,
        status: String,
        logoImage: PlatformImage?,
        businessDetailsLines: [String]
    ) {
        drawInspectionHeader(
            title: title,
            propertyName: propertyName,
            address: address,
            inspectionType: inspectionType,
            logoImage: logoImage,
            businessDetailsLines: businessDetailsLines,
            metaColumns: [
                (String(localized: "pdf.meta.date"), date),
                (String(localized: "pdf.meta.inspector"), inspectorName),
                (String(localized: "pdf.meta.status"), status)
            ]
        )
    }

    private func drawInspectionHeader(
        title: String,
        propertyName: String,
        address: String,
        inspectionType: String,
        logoImage: PlatformImage?,
        businessDetailsLines: [String],
        metaColumns: [(String, String)]
    ) {
        ensureSpace(180)

        let textWidth = contentWidth - 96
        let leftX = margin
        let topY = cursorY

        drawText(title.uppercased(), style: labelStyle, rect: CGRect(x: leftX, y: topY, width: textWidth, height: 16))

        let titleHeight = measuredHeight(propertyName, style: titleStyle, width: textWidth)
        let titleY = topY + 14
        drawText(propertyName, style: titleStyle, rect: CGRect(x: leftX, y: titleY, width: textWidth, height: titleHeight))

        let addressY = titleY + titleHeight + 2
        let addressHeight = measuredHeight(address, style: bodyStyle, width: textWidth)
        drawText(address, style: bodyStyle.withColor(secondaryColor), rect: CGRect(x: leftX, y: addressY, width: textWidth, height: addressHeight))

        let typeY = addressY + addressHeight + 2
        let typeHeight = measuredHeight(inspectionType, style: bodyStyle.withColor(secondaryColor), width: textWidth)
        drawText(inspectionType, style: bodyStyle.withColor(secondaryColor), rect: CGRect(x: leftX, y: typeY, width: textWidth, height: typeHeight))

        if let logoImage {
            let logoRect = CGRect(x: pageRect.width - margin - 82, y: topY, width: 82, height: 82)
            drawImage(logoImage, in: logoRect)
        }

        var blockBottom = typeY + typeHeight

        if !businessDetailsLines.isEmpty {
            var businessY = blockBottom + 6
            for line in businessDetailsLines {
                let h = measuredHeight(line, style: smallStyle, width: textWidth)
                drawText(line, style: smallStyle, rect: CGRect(x: leftX, y: businessY, width: textWidth, height: h))
                businessY += h + 1
            }
            blockBottom = max(blockBottom, businessY)
        }

        let dividerY = blockBottom + 8
        drawDivider(y: dividerY)

        let columnY = dividerY + 8
        let columnCount = max(metaColumns.count, 1)
        let columnGap: CGFloat = columnCount > 2 ? 16 : 18
        let totalGap = columnGap * CGFloat(max(columnCount - 1, 0))
        let columnWidth = (contentWidth - totalGap) / CGFloat(columnCount)

        var metaBottom = columnY
        for (index, column) in metaColumns.enumerated() {
            let x = margin + (CGFloat(index) * (columnWidth + columnGap))
            drawText(column.0.uppercased(), style: labelStyle, rect: CGRect(x: x, y: columnY, width: columnWidth, height: 14))
            let valueHeight = measuredHeight(column.1, style: valueStyle, width: columnWidth)
            drawText(column.1, style: valueStyle, rect: CGRect(x: x, y: columnY + 13, width: columnWidth, height: valueHeight))
            metaBottom = max(metaBottom, columnY + 13 + valueHeight)
        }

        cursorY = metaBottom + 8
    }

    func drawComparisonHeader(
        title: String,
        propertyName: String,
        address: String,
        previous: String,
        current: String,
        logoImage: PlatformImage?,
        businessDetailsLines: [String]
    ) {
        drawInspectionHeader(
            title: title,
            propertyName: propertyName,
            address: address,
            inspectionType: "",
            logoImage: logoImage,
            businessDetailsLines: businessDetailsLines,
            metaColumns: [
                (String(localized: "comparison.previous"), previous),
                (String(localized: "comparison.current"), current)
            ]
        )
    }

    func drawSummaryRow(_ metrics: [(String, Int)]) {
        ensureSpace(52)
        let dividerCount = max(metrics.count - 1, 0)
        let metricWidth = (contentWidth - CGFloat(dividerCount)) / CGFloat(metrics.count)
        let y = cursorY

        for (index, metric) in metrics.enumerated() {
            let x = margin + (CGFloat(index) * (metricWidth + 1))
            drawText("\(metric.1)", style: Style(
                font: UIFont(name: "TimesNewRomanPS-BoldMT", size: 25) ?? .boldSystemFont(ofSize: 25),
                color: primaryColor
            ), rect: CGRect(x: x, y: y, width: metricWidth, height: 30))
            drawText(metric.0.uppercased(), style: Style(font: UIFont.systemFont(ofSize: 9.5, weight: .semibold), color: secondaryColor), rect: CGRect(x: x, y: y + 24, width: metricWidth, height: 14))

            if index < metrics.count - 1 {
                drawVerticalDivider(
                    x: x + metricWidth,
                    y: y + 2,
                    height: 34
                )
            }
        }

        cursorY += 42
    }

    func drawSectionHeader(title: String, subtitle: String?, showsDivider: Bool = true) {
        ensureSpace(40)
        let titleHeight = measuredHeight(title, style: sectionTitleStyle, width: contentWidth)
        drawText(title, style: sectionTitleStyle, rect: CGRect(x: margin, y: cursorY, width: contentWidth, height: titleHeight))
        cursorY += titleHeight + 2

        if let subtitle, !subtitle.isEmpty {
            let subtitleStyle = Style(font: UIFont.systemFont(ofSize: 10.5, weight: .regular), color: secondaryColor)
            let subtitleHeight = measuredHeight(subtitle, style: subtitleStyle, width: contentWidth)
            drawText(subtitle, style: subtitleStyle, rect: CGRect(x: margin, y: cursorY, width: contentWidth, height: subtitleHeight))
            cursorY += subtitleHeight + 4
        }

        if showsDivider {
            drawDivider(y: cursorY)
            cursorY += 6
        }
    }

    func drawBodyText(_ text: String) {
        let height = measuredHeight(text, style: bodyStyle, width: contentWidth)
        ensureSpace(height + 2)
        drawText(text, style: bodyStyle, rect: CGRect(x: margin, y: cursorY, width: contentWidth, height: height))
        cursorY += height
    }

    func drawInspectionSection(
        title: String,
        subtitle: String,
        items: [ReportItem],
        evidenceImages: [UUID: PlatformImage]
    ) {
        guard !items.isEmpty else { return }
        let firstEstimate = estimatedInspectionItemHeight(
            items[0],
            image: evidenceImages[items[0].inspectionItem.id]
        )
        ensureSpace(48 + firstEstimate)
        drawSectionHeader(title: title, subtitle: subtitle)
        for (index, item) in items.enumerated() {
            let rowEstimate = estimatedInspectionItemHeight(item, image: evidenceImages[item.inspectionItem.id])
            ensureSpace(rowEstimate + 8)
            drawInspectionItem(item, image: evidenceImages[item.inspectionItem.id])
            if index < items.count - 1 {
                drawDivider(y: cursorY + 3)
                cursorY += 8
            }
        }
        cursorY += 10
    }

    func drawComparisonSection(
        title: String,
        subtitle: String,
        items: [DiffItem],
        evidenceImages: [String: PlatformImage]
    ) {
        guard !items.isEmpty else { return }
        let firstEstimate = estimatedComparisonItemHeight(
            items[0],
            oldImage: image(for: items[0].oldImage, source: evidenceImages),
            newImage: image(for: items[0].newImage, source: evidenceImages)
        )
        ensureSpace(48 + firstEstimate)
        drawSectionHeader(title: title, subtitle: subtitle, showsDivider: false)
        cursorY += 4
        for (index, item) in items.enumerated() {
            let oldImage = image(for: item.oldImage, source: evidenceImages)
            let newImage = image(for: item.newImage, source: evidenceImages)
            let rowEstimate = estimatedComparisonItemHeight(item, oldImage: oldImage, newImage: newImage)
            ensureSpace(rowEstimate + 8)
            drawComparisonItem(
                item,
                oldImage: oldImage,
                newImage: newImage
            )
            if index < items.count - 1 {
                drawDivider(y: cursorY + 3)
                cursorY += 8
            }
        }
        cursorY += 10
    }

    func drawComparisonTotals(changed: Int, unchanged: Int) {
        ensureSpace(40)
        let totalsStyle = Style(font: UIFont.systemFont(ofSize: 12.5, weight: .medium), color: primaryColor)
        let changedLine = "\(String(localized: "comparison_pdf.changed")): \(changed)"
        let unchangedLine = "\(String(localized: "comparison_pdf.unchanged")): \(unchanged)"

        let changedHeight = measuredHeight(changedLine, style: totalsStyle, width: contentWidth)
        drawText(
            changedLine,
            style: totalsStyle,
            rect: CGRect(x: margin, y: cursorY, width: contentWidth, height: changedHeight)
        )
        cursorY += changedHeight + 2

        let unchangedHeight = measuredHeight(unchangedLine, style: totalsStyle, width: contentWidth)
        drawText(
            unchangedLine,
            style: totalsStyle,
            rect: CGRect(x: margin, y: cursorY, width: contentWidth, height: unchangedHeight)
        )
        cursorY += unchangedHeight
    }

    func drawInspectionTotals(anomalies: Int, resolved: Int, present: Int) {
        ensureSpace(56)
        let totalsStyle = Style(font: UIFont.systemFont(ofSize: 12.5, weight: .medium), color: primaryColor)
        let lines = [
            "\(String(localized: "pdf.summary.anomalies")): \(anomalies)",
            "\(String(localized: "pdf.summary.resolved")): \(resolved)",
            "\(String(localized: "pdf.summary.present")): \(present)"
        ]

        for (index, line) in lines.enumerated() {
            let height = measuredHeight(line, style: totalsStyle, width: contentWidth)
            drawText(
                line,
                style: totalsStyle,
                rect: CGRect(x: margin, y: cursorY, width: contentWidth, height: height)
            )
            cursorY += height
            if index < lines.count - 1 {
                cursorY += 2
            }
        }
    }

    func drawFooter(_ text: String) {
        ensureSpace(22)
        drawDivider(y: cursorY)
        let footerStyle = Style(font: UIFont.systemFont(ofSize: 9.5, weight: .regular), color: secondaryColor)
        let h = measuredHeight(text, style: footerStyle, width: contentWidth)
        drawText(text, style: footerStyle, rect: CGRect(x: margin, y: cursorY + 6, width: contentWidth, height: h), alignment: .center)
        cursorY += h + 10
    }

    private func drawInspectionItem(_ item: ReportItem, image: PlatformImage?) {
        let startY = cursorY
        let leftX = margin
        let rightX = margin + detailColumnWidth + 14
        let columnDividerX = leftX + detailColumnWidth + 7
        let notes = item.inspectionItem.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let statusText = inspectionStatusLabel(item.inspectionItem.status, previousStatus: item.inspectionItem.previous_status)
        var leftY = startY

        let titleHeight = measuredHeight(item.inventoryItem.name, style: itemTitleStyle, width: detailColumnWidth)
        drawText(
            item.inventoryItem.name,
            style: itemTitleStyle,
            rect: CGRect(x: leftX, y: leftY, width: detailColumnWidth, height: titleHeight)
        )
        leftY += titleHeight + 1

        let roomHeight = measuredHeight(item.room.name, style: smallStyle, width: detailColumnWidth)
        drawText(
            item.room.name,
            style: smallStyle,
            rect: CGRect(x: leftX, y: leftY, width: detailColumnWidth, height: roomHeight)
        )
        leftY += roomHeight + 2

        let statusStyle = Style(font: UIFont.systemFont(ofSize: 9, weight: .semibold), color: statusColor(item.inspectionItem.status))
        let statusLine = statusText.uppercased()
        let statusHeight = measuredHeight(statusLine, style: statusStyle, width: detailColumnWidth)
        drawText(
            statusLine,
            style: statusStyle,
            rect: CGRect(x: leftX, y: leftY, width: detailColumnWidth, height: statusHeight)
        )
        leftY += statusHeight + 2

        if !notes.isEmpty {
            let notesHeight = measuredHeight(notes, style: bodyStyle, width: detailColumnWidth)
            drawText(
                notes,
                style: bodyStyle,
                rect: CGRect(x: leftX, y: leftY, width: detailColumnWidth, height: notesHeight)
            )
            leftY += notesHeight
        }

        let shouldRenderPhoto = isIssueStatus(item.inspectionItem.status)
        var rightY = startY
        if shouldRenderPhoto, let image {
            let photoLabelStyle = Style(font: UIFont.systemFont(ofSize: 8.5, weight: .semibold), color: secondaryColor)
            drawText(
                String(localized: "pdf.photo_evidence").uppercased(),
                style: photoLabelStyle,
                rect: CGRect(x: rightX, y: rightY, width: photoColumnWidth, height: 11)
            )
            rightY += 11

            let imageRect = fittedImageRect(
                for: image,
                maxWidth: photoColumnWidth,
                maxHeight: 220,
                x: rightX,
                y: rightY
            )
            drawImage(image, in: imageRect)
            rightY += imageRect.height
        }

        let rowBottom = max(leftY, rightY) + 3
        if shouldRenderPhoto {
            drawVerticalDivider(
                x: columnDividerX,
                y: startY,
                height: max(1, rowBottom - startY - 1)
            )
        }
        cursorY = rowBottom
    }

    private func drawComparisonItem(_ item: DiffItem, oldImage: PlatformImage?, newImage: PlatformImage?) {
        let startY = cursorY
        let leftX = margin
        let rightX = margin + detailColumnWidth + 14
        let columnDividerX = leftX + detailColumnWidth + 7
        let notes = item.newNotes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let slotHeight: CGFloat = 132
        let blockGap: CGFloat = 4
        let headerToCellsGap: CGFloat = 4

        let titleHeight = measuredHeight(item.itemName, style: itemTitleStyle, width: detailColumnWidth)
        drawText(
            item.itemName,
            style: itemTitleStyle,
            rect: CGRect(x: leftX, y: startY, width: detailColumnWidth, height: titleHeight)
        )
        var leftY = startY + titleHeight + 1

        let roomHeight = measuredHeight(item.roomName, style: smallStyle, width: detailColumnWidth)
        drawText(
            item.roomName,
            style: smallStyle,
            rect: CGRect(x: leftX, y: leftY, width: detailColumnWidth, height: roomHeight)
        )
        leftY += roomHeight + 2

        // Keep item/room as a compact heading above both previous/current cells.
        let headerDividerY = leftY
        drawDivider(y: headerDividerY, fromX: leftX, toX: rightX + photoColumnWidth)
        let cellsTopY = headerDividerY + headerToCellsGap
        leftY = cellsTopY

        let shouldRenderPhotos = shouldRenderComparisonPhotos(oldStatus: item.oldStatus, newStatus: item.newStatus)
        let sectionLabelStyle = Style(font: UIFont.systemFont(ofSize: 9, weight: .semibold), color: secondaryColor)
        let oldStatusStyle = Style(font: UIFont.systemFont(ofSize: 8.5, weight: .semibold), color: statusColor(item.oldStatus))
        let newStatusStyle = Style(font: UIFont.systemFont(ofSize: 8.5, weight: .semibold), color: statusColor(item.newStatus))
        let previousStatusText = localizedStatus(item.oldStatus).uppercased()
        let previousStatusHeight = measuredHeight(previousStatusText, style: oldStatusStyle, width: detailColumnWidth)
        let previousDetailHeight: CGFloat = 11 + previousStatusHeight + 3
        let previousPhotoHeight: CGFloat = shouldRenderPhotos ? (11 + slotHeight + 2) : 0
        let topBlockHeight = max(previousDetailHeight, previousPhotoHeight)

        let previousLabel = String(localized: "comparison.previous").uppercased()
        drawText(previousLabel, style: sectionLabelStyle, rect: CGRect(x: leftX, y: leftY, width: detailColumnWidth, height: 11))
        leftY += 11

        drawText(previousStatusText, style: oldStatusStyle, rect: CGRect(x: leftX, y: leftY, width: detailColumnWidth, height: previousStatusHeight))

        if shouldRenderPhotos {
            _ = drawComparisonPhotoSlot(
                label: String(localized: "comparison.previous"),
                image: oldImage,
                x: rightX,
                y: leftY - 11,
                slotHeight: slotHeight
            )
        }

        let splitY = (leftY - 11) + topBlockHeight
        drawDivider(
            y: splitY,
            fromX: leftX,
            toX: shouldRenderPhotos ? (rightX + photoColumnWidth) : (leftX + detailColumnWidth)
        )

        let currentStartY = splitY + blockGap
        leftY = currentStartY
        let currentLabel = String(localized: "comparison.current").uppercased()
        drawText(currentLabel, style: sectionLabelStyle, rect: CGRect(x: leftX, y: leftY, width: detailColumnWidth, height: 11))
        leftY += 11

        let currentStatusText = localizedStatus(item.newStatus).uppercased()
        let currentStatusHeight = measuredHeight(currentStatusText, style: newStatusStyle, width: detailColumnWidth)
        drawText(currentStatusText, style: newStatusStyle, rect: CGRect(x: leftX, y: leftY, width: detailColumnWidth, height: currentStatusHeight))
        leftY += currentStatusHeight + 2

        if !notes.isEmpty {
            let notesHeight = measuredHeight(notes, style: bodyStyle, width: detailColumnWidth)
            drawText(
                notes,
                style: bodyStyle,
                rect: CGRect(x: leftX, y: leftY, width: detailColumnWidth, height: notesHeight)
            )
            leftY += notesHeight
        }

        let rightY: CGFloat
        if shouldRenderPhotos {
            rightY = drawComparisonPhotoSlot(
                label: String(localized: "comparison.current"),
                image: newImage,
                x: rightX,
                y: currentStartY,
                slotHeight: slotHeight
            )
        } else {
            rightY = startY
        }

        let rowBottom = max(leftY, rightY) + 3
        if shouldRenderPhotos {
            drawVerticalDivider(
                x: columnDividerX,
                y: cellsTopY,
                height: max(1, rowBottom - cellsTopY - 1)
            )
        }
        cursorY = rowBottom
    }

    private func drawComparisonPhotoSlot(label: String, image: PlatformImage?, x: CGFloat, y: CGFloat, slotHeight: CGFloat) -> CGFloat {
        let captionStyle = Style(font: UIFont.systemFont(ofSize: 8.5, weight: .semibold), color: secondaryColor)
        drawText(label.uppercased(), style: captionStyle, rect: CGRect(x: x, y: y, width: photoColumnWidth, height: 11))

        let slotY = y + 11
        let slotRect = CGRect(x: x, y: slotY, width: photoColumnWidth, height: slotHeight)

        if let image {
            drawImageAspectFit(image, in: slotRect.insetBy(dx: 4, dy: 4))
        } else {
            drawPhotoPlaceholder(in: slotRect.insetBy(dx: 4, dy: 4))
        }

        return slotRect.maxY + 2
    }

    private func drawDivider(y: CGFloat) {
        drawDivider(y: y, fromX: margin, toX: pageRect.width - margin)
    }

    private func drawDivider(y: CGFloat, fromX: CGFloat, toX: CGFloat) {
        guard let cg = context?.cgContext else { return }
        cg.saveGState()
        cg.setStrokeColor(dividerColor.cgColor)
        cg.setLineWidth(1)
        cg.move(to: CGPoint(x: fromX, y: y))
        cg.addLine(to: CGPoint(x: toX, y: y))
        cg.strokePath()
        cg.restoreGState()
    }

    private func drawVerticalDivider(x: CGFloat, y: CGFloat, height: CGFloat) {
        guard let cg = context?.cgContext else { return }
        cg.saveGState()
        cg.setStrokeColor(dividerColor.cgColor)
        cg.setLineWidth(1)
        cg.move(to: CGPoint(x: x, y: y))
        cg.addLine(to: CGPoint(x: x, y: y + height))
        cg.strokePath()
        cg.restoreGState()
    }

    private func drawText(_ text: String, style: Style, rect: CGRect, alignment: NSTextAlignment = .left) {
        guard !text.isEmpty else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: style.font,
                .foregroundColor: style.color,
                .paragraphStyle: paragraph
            ]
        )
        attributed.draw(with: rect.integral, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    private func measuredHeight(_ text: String, style: Style, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: style.font, .paragraphStyle: paragraph],
            context: nil
        )
        return ceil(rect.height)
    }

    private func measuredWidth(_ text: String, style: Style) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: style.font],
            context: nil
        )
        return ceil(rect.width)
    }

    private func drawImage(_ image: PlatformImage, in rect: CGRect) {
        image.draw(in: rect)
    }

    private func drawImageAspectFit(_ image: PlatformImage, in bounds: CGRect) {
        let fit = fittedImageRect(
            for: image,
            maxWidth: bounds.width,
            maxHeight: bounds.height,
            x: 0,
            y: 0
        )
        let centered = CGRect(
            x: bounds.minX + ((bounds.width - fit.width) / 2),
            y: bounds.minY + ((bounds.height - fit.height) / 2),
            width: fit.width,
            height: fit.height
        )
        image.draw(in: centered)
    }

    private func drawRectStroke(_ rect: CGRect, color: UIColor, lineWidth: CGFloat) {
        guard let cg = context?.cgContext else { return }
        cg.saveGState()
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(lineWidth)
        cg.stroke(rect)
        cg.restoreGState()
    }

    private func drawPhotoPlaceholder(in rect: CGRect) {
        let placeholderStyle = Style(font: UIFont.systemFont(ofSize: 9, weight: .semibold), color: secondaryColor)
        drawText(
            String(localized: "pdf.no_photo").uppercased(),
            style: placeholderStyle,
            rect: CGRect(
                x: rect.minX,
                y: rect.midY - 6,
                width: rect.width,
                height: 12
            ),
            alignment: .center
        )
    }

    private func fittedImageRect(for image: PlatformImage, maxWidth: CGFloat, maxHeight: CGFloat, x: CGFloat, y: CGFloat) -> CGRect {
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            return CGRect(x: x, y: y, width: maxWidth, height: maxHeight)
        }

        let widthRatio = maxWidth / size.width
        let heightRatio = maxHeight / size.height
        let scale = min(widthRatio, heightRatio)
        let width = max(1, size.width * scale)
        let height = max(1, size.height * scale)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func image(for path: String?, source: [String: PlatformImage]) -> PlatformImage? {
        guard let path else { return nil }
        if let normalized = InspectionImageStorage.normalizePath(path),
           let normalizedImage = source[normalized] {
            return normalizedImage
        }
        return source[path]
    }

    private func localizedStatus(_ status: String) -> String {
        switch status.lowercased() {
        case "missing":
            return String(localized: "inspection_item.status.missing")
        case "damaged":
            return String(localized: "inspection_item.status.damaged")
        case "resolved":
            return String(localized: "inspection_item.status.resolved")
        case "pending":
            return String(localized: "inspection_item.status.pending")
        case "present":
            return String(localized: "inspection_item.status.present")
        default:
            return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func inspectionStatusLabel(_ status: String, previousStatus: String?) -> String {
        if status == "resolved", let previousStatus, isResolvableIssue(previousStatus) {
            return String.localizedStringWithFormat(
                NSLocalizedString("pdf.status.resolved_from", comment: ""),
                inspectionStatusLabel(previousStatus, previousStatus: nil)
            )
        }

        switch status {
        case "damaged":
            return String(localized: "inspection_item.status.damaged")
        case "missing":
            return String(localized: "inspection_item.status.missing")
        case "resolved":
            return String(localized: "pdf.summary.resolved")
        case "present":
            return String(localized: "report.present_intact")
        default:
            return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func statusColor(_ status: String) -> UIColor {
        switch status.lowercased() {
        case "damaged":
            return UIColor(red: 0.74, green: 0.22, blue: 0.22, alpha: 1)
        case "missing":
            return UIColor(red: 0.70, green: 0.45, blue: 0.16, alpha: 1)
        case "resolved":
            return UIColor(red: 0.12, green: 0.38, blue: 0.65, alpha: 1)
        case "present":
            return UIColor(red: 0.20, green: 0.48, blue: 0.30, alpha: 1)
        default:
            return secondaryColor
        }
    }

    private func isResolvableIssue(_ status: String) -> Bool {
        status == "missing" || status == "damaged"
    }

    private func estimatedInspectionItemHeight(_ item: ReportItem, image: PlatformImage?) -> CGFloat {
        let notes = item.inspectionItem.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var leftHeight: CGFloat = 0
        leftHeight += measuredHeight(item.inventoryItem.name, style: itemTitleStyle, width: detailColumnWidth) + 1
        leftHeight += measuredHeight(item.room.name, style: smallStyle, width: detailColumnWidth) + 2
        let statusStyle = Style(font: UIFont.systemFont(ofSize: 9, weight: .semibold), color: statusColor(item.inspectionItem.status))
        leftHeight += measuredHeight(
            inspectionStatusLabel(item.inspectionItem.status, previousStatus: item.inspectionItem.previous_status).uppercased(),
            style: statusStyle,
            width: detailColumnWidth
        ) + 2
        if !notes.isEmpty {
            leftHeight += measuredHeight(notes, style: bodyStyle, width: detailColumnWidth)
        }

        var rightHeight: CGFloat = 0
        if isIssueStatus(item.inspectionItem.status), let image {
            rightHeight += 11
            rightHeight += fittedImageRect(for: image, maxWidth: photoColumnWidth, maxHeight: 220, x: 0, y: 0).height
        }

        return max(leftHeight, rightHeight) + 3
    }

    private func estimatedComparisonItemHeight(_ item: DiffItem, oldImage: PlatformImage?, newImage: PlatformImage?) -> CGFloat {
        let notes = item.newNotes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let slotHeight: CGFloat = 132
        let blockGap: CGFloat = 4
        let headerToCellsGap: CGFloat = 4
        var leftHeight: CGFloat = 0
        leftHeight += measuredHeight(item.itemName, style: itemTitleStyle, width: detailColumnWidth) + 1
        leftHeight += measuredHeight(item.roomName, style: smallStyle, width: detailColumnWidth) + 2
        leftHeight += headerToCellsGap

        let oldStatusStyle = Style(font: UIFont.systemFont(ofSize: 8.5, weight: .semibold), color: statusColor(item.oldStatus))
        let newStatusStyle = Style(font: UIFont.systemFont(ofSize: 8.5, weight: .semibold), color: statusColor(item.newStatus))
        let shouldRenderPhotos = shouldRenderComparisonPhotos(oldStatus: item.oldStatus, newStatus: item.newStatus)
        let previousDetailHeight = 11 + measuredHeight(localizedStatus(item.oldStatus).uppercased(), style: oldStatusStyle, width: detailColumnWidth) + 3
        let previousPhotoHeight: CGFloat = shouldRenderPhotos ? (11 + slotHeight + 2) : 0
        let topBlockHeight = max(previousDetailHeight, previousPhotoHeight)

        var currentDetailHeight = 11 + measuredHeight(localizedStatus(item.newStatus).uppercased(), style: newStatusStyle, width: detailColumnWidth) + 2
        if !notes.isEmpty {
            currentDetailHeight += measuredHeight(notes, style: bodyStyle, width: detailColumnWidth)
        }
        let currentPhotoHeight: CGFloat = shouldRenderPhotos ? (11 + slotHeight + 2) : 0
        let bottomBlockHeight = max(currentDetailHeight, currentPhotoHeight)

        _ = oldImage
        _ = newImage
        leftHeight += topBlockHeight + blockGap + bottomBlockHeight
        return leftHeight + 3
    }

    private func shouldRenderComparisonPhotos(oldStatus: String, newStatus: String) -> Bool {
        isIssueStatus(oldStatus) || isIssueStatus(newStatus)
    }

    private func isIssueStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized == "missing" || normalized == "damaged"
    }
}

private extension PDFPainter.Style {
    func withColor(_ color: UIColor) -> PDFPainter.Style {
        PDFPainter.Style(font: font, color: color)
    }
}

#else

struct PDFReportGenerator {
    static func generate(
        inspection: InspectionModel,
        property: PropertyModel?,
        inspectorName: String?,
        anomalies: [ReportItem],
        presentItems: [ReportItem] = [],
        resolvedItems: [ReportItem] = [],
        evidenceImages: [UUID: PlatformImage] = [:],
        logoImage: PlatformImage? = nil,
        isWhiteLabel: Bool = false,
        businessDetailsLines: [String] = []
    ) -> Data {
        Data()
    }

    static func generateComparison(
        older: InspectionModel,
        newer: InspectionModel,
        property: PropertyModel?,
        previousInspectorName: String?,
        currentInspectorName: String?,
        changedItems: [DiffItem],
        unchangedItems: [DiffItem],
        evidenceImages: [String: PlatformImage] = [:],
        logoImage: PlatformImage? = nil,
        isWhiteLabel: Bool = false,
        businessDetailsLines: [String] = []
    ) -> Data {
        Data()
    }
}

#endif
