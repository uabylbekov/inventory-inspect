import UIKit
import PDFKit

struct PDFReportGenerator {

    static func generate(
        inspection: InspectionModel,
        property: PropertyModel?,
        inspectorName: String?,
        anomalies: [ReportItem],
        presentItems: [ReportItem] = [],
        resolvedItems: [ReportItem] = [],
        logoImage: UIImage? = nil,
        isWhiteLabel: Bool = false
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var yOffset: CGFloat = 40

            let accentColor = UIColor(red: 0.11, green: 0.34, blue: 0.87, alpha: 1)
            let borderColor = UIColor(red: 0.88, green: 0.90, blue: 0.94, alpha: 1)
            let panelColor = UIColor(red: 0.96, green: 0.97, blue: 0.985, alpha: 1)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.black
            ]
            let boldBodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let secondaryAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: UIColor.darkGray
            ]

            UIColor.white.setFill()
            ctx.fill(pageRect)

            if let logo = logoImage {
                let logoSize: CGFloat = 60
                let logoRect = CGRect(x: pageRect.width - 40 - logoSize, y: yOffset, width: logoSize, height: logoSize)
                logo.draw(in: logoRect)
            }

            let dateStr = formatDate(inspection.started_at)
            let title = property?.name ?? "Inspection Report"
            NSAttributedString(string: "COMPARISON REPORT", attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: accentColor
            ]).draw(at: CGPoint(x: 40, y: yOffset))
            yOffset += 18

            title.draw(at: CGPoint(x: 40, y: yOffset), withAttributes: titleAttrs)
            yOffset += 28

            NSAttributedString(
                string: property?.address_line1 ?? "—",
                attributes: bodyAttrs
            ).draw(at: CGPoint(x: 40, y: yOffset))
            yOffset += 28

            let typeName = formatType(inspection.inspection_type)
            let topMeta: [(String, String)] = [
                ("Inspection Type", typeName),
                ("Date", dateStr),
                ("Inspector", inspectorName ?? "Unknown")
            ]
            let cardWidth = (pageRect.width - 80 - 24) / 3
            for (index, entry) in topMeta.enumerated() {
                let x = 40 + (CGFloat(index) * (cardWidth + 12))
                drawMetaCard(
                    label: entry.0,
                    value: entry.1,
                    rect: CGRect(x: x, y: yOffset, width: cardWidth, height: 56),
                    fill: panelColor,
                    stroke: borderColor,
                    labelAttrs: labelAttrs,
                    valueAttrs: boldBodyAttrs
                )
            }
            yOffset += 76

            let total = anomalies.count + presentItems.count
            let summaryCards: [(String, String, UIColor)] = [
                ("Total Checked", "\(total)", .black),
                ("Issues Found", "\(anomalies.count)", anomalies.isEmpty ? .black : .systemRed),
                ("Present & Intact", "\(presentItems.count)", .systemGreen)
            ]
            let summaryWidth = (pageRect.width - 80 - 24) / 3
            for (index, entry) in summaryCards.enumerated() {
                let x = 40 + (CGFloat(index) * (summaryWidth + 12))
                drawSummaryCard(
                    title: entry.0,
                    value: entry.1,
                    color: entry.2,
                    rect: CGRect(x: x, y: yOffset, width: summaryWidth, height: 72),
                    fill: UIColor.white,
                    stroke: borderColor
                )
            }
            yOffset += 96

            if !anomalies.isEmpty {
                yOffset = checkPageBreak(ctx: ctx, y: yOffset, pageRect: pageRect)
                drawSectionTitle(
                    title: "Issues Found",
                    subtitle: "\(anomalies.count) items require attention",
                    at: CGPoint(x: 40, y: yOffset),
                    titleColor: .black,
                    subtitleAttrs: secondaryAttrs
                )
                yOffset += 34

                for item in anomalies {
                    yOffset = checkPageBreak(ctx: ctx, y: yOffset, pageRect: pageRect)
                    let statusColor: UIColor = item.inspectionItem.status == "missing" ? .systemOrange : .systemRed
                    let statusLabel = item.inspectionItem.status.capitalized
                    let rowHeight: CGFloat = (item.inspectionItem.notes?.isEmpty == false) ? 66 : 50
                    drawItemCardBackground(
                        rect: CGRect(x: 40, y: yOffset - 2, width: pageRect.width - 80, height: rowHeight),
                        accent: statusColor,
                        stroke: borderColor
                    )

                    NSAttributedString(string: item.inventoryItem.name, attributes: boldBodyAttrs).draw(at: CGPoint(x: 58, y: yOffset + 8))
                    NSAttributedString(string: item.room.name, attributes: secondaryAttrs).draw(at: CGPoint(x: 58, y: yOffset + 24))
                    drawStatusPill(
                        label: statusLabel,
                        color: statusColor,
                        origin: CGPoint(x: pageRect.width - 134, y: yOffset + 9)
                    )

                    if let notes = item.inspectionItem.notes, !notes.isEmpty {
                        NSAttributedString(string: notes, attributes: secondaryAttrs).draw(in: CGRect(x: 58, y: yOffset + 40, width: pageRect.width - 170, height: 18))
                        yOffset += 74
                    } else {
                        yOffset += 58
                    }
                }
                yOffset += 12
            }

            if !presentItems.isEmpty {
                yOffset = checkPageBreak(ctx: ctx, y: yOffset, pageRect: pageRect)
                drawSectionTitle(
                    title: "Present & Intact",
                    subtitle: "\(presentItems.count) items were present and intact",
                    at: CGPoint(x: 40, y: yOffset),
                    titleColor: .black,
                    subtitleAttrs: secondaryAttrs
                )
                yOffset += 34

                let grouped = Dictionary(grouping: presentItems, by: { $0.room.name })
                for (roomName, items) in grouped.sorted(by: { $0.key < $1.key }) {
                    yOffset = checkPageBreak(ctx: ctx, y: yOffset, pageRect: pageRect)
                    NSAttributedString(string: roomName.uppercased(), attributes: [
                        .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                        .foregroundColor: UIColor.gray
                    ]).draw(at: CGPoint(x: 52, y: yOffset))
                    yOffset += 16

                    for item in items {
                        yOffset = checkPageBreak(ctx: ctx, y: yOffset, pageRect: pageRect)
                        let check = NSAttributedString(string: "•  \(item.inventoryItem.name)", attributes: bodyAttrs)
                        check.draw(at: CGPoint(x: 52, y: yOffset))
                        yOffset += 16
                    }
                    yOffset += 6
                }
            }

            let footer = isWhiteLabel
                ? "Generated on \(dateStr)"
                : "Generated by Snapshots • \(dateStr)"
            NSAttributedString(string: footer, attributes: secondaryAttrs)
                .draw(at: CGPoint(x: 40, y: pageRect.height - 30))
        }
    }

    static func generateComparison(
        older: InspectionModel,
        newer: InspectionModel,
        property: PropertyModel?,
        inspectorName: String?,
        changedItems: [DiffItem],
        unchangedItems: [DiffItem],
        logoImage: UIImage? = nil,
        isWhiteLabel: Bool = false
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var yOffset: CGFloat = 40

            let accentColor = UIColor(red: 0.11, green: 0.34, blue: 0.87, alpha: 1)
            let borderColor = UIColor(red: 0.88, green: 0.90, blue: 0.94, alpha: 1)
            let panelColor = UIColor(red: 0.96, green: 0.97, blue: 0.985, alpha: 1)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.black
            ]
            let boldBodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let secondaryAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: UIColor.darkGray
            ]

            UIColor.white.setFill()
            ctx.fill(pageRect)

            if let logo = logoImage {
                let logoSize: CGFloat = 60
                let logoRect = CGRect(x: pageRect.width - 40 - logoSize, y: yOffset, width: logoSize, height: logoSize)
                logo.draw(in: logoRect)
            }

            NSAttributedString(string: "COMPARISON REPORT", attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: accentColor
            ]).draw(at: CGPoint(x: 40, y: yOffset))
            yOffset += 18

            (property?.name ?? "Inspection Comparison").draw(at: CGPoint(x: 40, y: yOffset), withAttributes: titleAttrs)
            yOffset += 28

            NSAttributedString(
                string: property?.address_line1 ?? "—",
                attributes: bodyAttrs
            ).draw(at: CGPoint(x: 40, y: yOffset))
            yOffset += 28

            let topMeta: [(String, String)] = [
                ("Previous", "\(formatType(older.inspection_type)) • \(formatDate(older.completed_at ?? older.started_at))"),
                ("Current", "\(formatType(newer.inspection_type)) • \(formatDate(newer.completed_at ?? newer.started_at))"),
                ("Inspector", inspectorName ?? "Unknown")
            ]
            let cardWidth = (pageRect.width - 80 - 24) / 3
            for (index, entry) in topMeta.enumerated() {
                let x = 40 + (CGFloat(index) * (cardWidth + 12))
                drawMetaCard(
                    label: entry.0,
                    value: entry.1,
                    rect: CGRect(x: x, y: yOffset, width: cardWidth, height: 64),
                    fill: panelColor,
                    stroke: borderColor,
                    labelAttrs: labelAttrs,
                    valueAttrs: boldBodyAttrs
                )
            }
            yOffset += 84

            let summaryCards: [(String, String, UIColor)] = [
                ("Changed Items", "\(changedItems.count)", changedItems.isEmpty ? .black : .systemRed),
                ("Unchanged Items", "\(unchangedItems.count)", .darkGray),
                ("Current Issues", "\(changedItems.filter { isIssueStatus($0.newStatus) }.count)", .systemOrange)
            ]
            let summaryWidth = (pageRect.width - 80 - 24) / 3
            for (index, entry) in summaryCards.enumerated() {
                let x = 40 + (CGFloat(index) * (summaryWidth + 12))
                drawSummaryCard(
                    title: entry.0,
                    value: entry.1,
                    color: entry.2,
                    rect: CGRect(x: x, y: yOffset, width: summaryWidth, height: 72),
                    fill: UIColor.white,
                    stroke: borderColor
                )
            }
            yOffset += 96

            if !changedItems.isEmpty {
                yOffset = checkPageBreak(ctx: ctx, y: yOffset, pageRect: pageRect)
                drawSectionTitle(
                    title: "Changed Items",
                    subtitle: "\(changedItems.count) items changed since the previous inspection",
                    at: CGPoint(x: 40, y: yOffset),
                    titleColor: .black,
                    subtitleAttrs: secondaryAttrs
                )
                yOffset += 36

                for diff in changedItems {
                    yOffset = checkPageBreak(ctx: ctx, y: yOffset + 80, pageRect: pageRect)
                    let rowHeight: CGFloat = comparisonRowHeight(for: diff)
                    drawItemCardBackground(
                        rect: CGRect(x: 40, y: yOffset - 2, width: pageRect.width - 80, height: rowHeight),
                        accent: statusColor(diff.newStatus),
                        stroke: borderColor
                    )

                    NSAttributedString(string: diff.itemName, attributes: boldBodyAttrs).draw(at: CGPoint(x: 58, y: yOffset + 8))
                    NSAttributedString(string: diff.roomName, attributes: secondaryAttrs).draw(at: CGPoint(x: 58, y: yOffset + 24))

                    let leftX: CGFloat = 58
                    let rightX: CGFloat = 320
                    let statusY = yOffset + 44
                    NSAttributedString(string: "Previous", attributes: labelAttrs).draw(at: CGPoint(x: leftX, y: statusY))
                    drawStatusPill(label: statusLabel(diff.oldStatus), color: statusColor(diff.oldStatus), origin: CGPoint(x: leftX + 62, y: statusY - 2))
                    NSAttributedString(string: "Current", attributes: labelAttrs).draw(at: CGPoint(x: rightX, y: statusY))
                    drawStatusPill(label: currentStatusLabel(for: diff), color: statusColor(diff.newStatus), origin: CGPoint(x: rightX + 52, y: statusY - 2))

                    var notesY = statusY + 24
                    if let oldNotes = diff.oldNotes, !oldNotes.isEmpty {
                        NSAttributedString(string: "Previous notes: \(oldNotes)", attributes: secondaryAttrs)
                            .draw(in: CGRect(x: leftX, y: notesY, width: 230, height: 28))
                        notesY += 18
                    }
                    if let newNotes = diff.newNotes, !newNotes.isEmpty {
                        NSAttributedString(string: "Current notes: \(newNotes)", attributes: secondaryAttrs)
                            .draw(in: CGRect(x: leftX, y: notesY, width: pageRect.width - 160, height: 32))
                    }

                    yOffset += rowHeight + 10
                }
            }

            if !unchangedItems.isEmpty {
                yOffset = checkPageBreak(ctx: ctx, y: yOffset + 40, pageRect: pageRect)
                drawSectionTitle(
                    title: "Unchanged Items",
                    subtitle: "\(unchangedItems.count) items stayed the same",
                    at: CGPoint(x: 40, y: yOffset),
                    titleColor: .black,
                    subtitleAttrs: secondaryAttrs
                )
                yOffset += 36

                for diff in unchangedItems {
                    yOffset = checkPageBreak(ctx: ctx, y: yOffset + 28, pageRect: pageRect)
                    NSAttributedString(
                        string: "•  \(diff.itemName) (\(diff.roomName))",
                        attributes: bodyAttrs
                    ).draw(at: CGPoint(x: 52, y: yOffset))
                    drawStatusPill(
                        label: currentStatusLabel(for: diff),
                        color: statusColor(diff.newStatus),
                        origin: CGPoint(x: pageRect.width - 134, y: yOffset - 4)
                    )
                    yOffset += 20
                }
            }

            let footerDate = formatDate(newer.completed_at ?? newer.started_at)
            let footer = isWhiteLabel
                ? "Generated on \(footerDate)"
                : "Generated by Snapshots • \(footerDate)"
            NSAttributedString(string: footer, attributes: secondaryAttrs)
                .draw(at: CGPoint(x: 40, y: pageRect.height - 30))
        }
    }

    // MARK: - Helpers

    private static func drawMetaCard(
        label: String,
        value: String,
        rect: CGRect,
        fill: UIColor,
        stroke: UIColor,
        labelAttrs: [NSAttributedString.Key: Any],
        valueAttrs: [NSAttributedString.Key: Any]
    ) {
        fill.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 12).fill()
        stroke.setStroke()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        path.lineWidth = 1
        path.stroke()

        NSAttributedString(string: label, attributes: labelAttrs).draw(at: CGPoint(x: rect.minX + 12, y: rect.minY + 10))
        NSAttributedString(string: value, attributes: valueAttrs).draw(in: CGRect(x: rect.minX + 12, y: rect.minY + 26, width: rect.width - 24, height: 20))
    }

    private static func drawSummaryCard(
        title: String,
        value: String,
        color: UIColor,
        rect: CGRect,
        fill: UIColor,
        stroke: UIColor
    ) {
        fill.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 14).fill()
        stroke.setStroke()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 14)
        path.lineWidth = 1
        path.stroke()

        color.setFill()
        UIBezierPath(ovalIn: CGRect(x: rect.minX + 16, y: rect.minY + 16, width: 10, height: 10)).fill()

        NSAttributedString(string: value, attributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.black
        ]).draw(at: CGPoint(x: rect.minX + 16, y: rect.minY + 28))

        NSAttributedString(string: title, attributes: [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.darkGray
        ]).draw(at: CGPoint(x: rect.minX + 16, y: rect.minY + 52))
    }

    private static func drawSectionTitle(
        title: String,
        subtitle: String,
        at origin: CGPoint,
        titleColor: UIColor,
        subtitleAttrs: [NSAttributedString.Key: Any]
    ) {
        NSAttributedString(string: title, attributes: [
            .font: UIFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: titleColor
        ]).draw(at: origin)
        NSAttributedString(string: subtitle, attributes: subtitleAttrs).draw(at: CGPoint(x: origin.x, y: origin.y + 20))
    }

    private static func drawItemCardBackground(rect: CGRect, accent: UIColor, stroke: UIColor) {
        UIColor.white.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 12).fill()
        stroke.setStroke()
        let border = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        border.lineWidth = 1
        border.stroke()

        accent.setFill()
        UIBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: 6, height: rect.height), cornerRadius: 3).fill()
    }

    private static func drawStatusPill(label: String, color: UIColor, origin: CGPoint) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: color
        ]
        let text = NSAttributedString(string: label, attributes: attrs)
        let size = text.size()
        let rect = CGRect(x: origin.x, y: origin.y, width: size.width + 14, height: 20)
        color.withAlphaComponent(0.12).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
        text.draw(at: CGPoint(x: rect.minX + 7, y: rect.minY + 4))
    }

    private static func comparisonRowHeight(for diff: DiffItem) -> CGFloat {
        var height: CGFloat = 84
        if let oldNotes = diff.oldNotes, !oldNotes.isEmpty {
            height += 18
        }
        if let newNotes = diff.newNotes, !newNotes.isEmpty {
            height += 22
        }
        return height
    }

    private static func isIssueStatus(_ status: String) -> Bool {
        status == "missing" || status == "damaged"
    }

    private static func statusColor(_ status: String) -> UIColor {
        switch status {
        case "present":
            return .systemGreen
        case "missing":
            return .systemOrange
        case "damaged":
            return .systemRed
        case "resolved":
            return .systemBlue
        default:
            return .darkGray
        }
    }

    private static func statusLabel(_ status: String) -> String {
        switch status {
        case "present":
            return "Present & Intact"
        case "missing":
            return "Missing"
        case "damaged":
            return "Damaged"
        case "resolved":
            return "Resolved"
        default:
            return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func currentStatusLabel(for diff: DiffItem) -> String {
        if diff.newStatus == "resolved",
           let previousStatus = diff.newPreviousStatus,
           isIssueStatus(previousStatus) {
            return "Resolved from \(statusLabel(previousStatus))"
        }
        return statusLabel(diff.newStatus)
    }

    @discardableResult
    private static func checkPageBreak(ctx: UIGraphicsPDFRendererContext, y: CGFloat, pageRect: CGRect) -> CGFloat {
        if y > pageRect.height - 80 {
            ctx.beginPage()
            return 40
        }
        return y
    }

    private static func formatType(_ type: String) -> String {
        switch type {
        case "move-in": return "Move-In"
        case "move-out": return "Move-Out"
        case "routine": return "Routine"
        default: return type.capitalized
        }
    }

    private static func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: dateString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }
        guard let d = date else { return dateString }
        let display = DateFormatter()
        display.dateStyle = .long
        display.timeStyle = .short
        return display.string(from: d)
    }
}
