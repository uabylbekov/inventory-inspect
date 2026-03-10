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

            // ── Header ─────────────────────────────────────────────────────────
            let accentColor = UIColor.systemBlue
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

            // Draw logo if available (top-right corner)
            if let logo = logoImage {
                let logoSize: CGFloat = 60
                let logoRect = CGRect(x: pageRect.width - 40 - logoSize, y: yOffset, width: logoSize, height: logoSize)
                logo.draw(in: logoRect)
            }

            let title = property?.name ?? "Inspection Report"
            title.draw(at: CGPoint(x: 40, y: yOffset), withAttributes: titleAttrs)
            yOffset += 30

            // Type pill
            let typeName = formatType(inspection.inspection_type)
            let typeStr = NSAttributedString(string: typeName, attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.white
            ])
            let typeSize = typeStr.size()
            let pillRect = CGRect(x: 40, y: yOffset, width: typeSize.width + 16, height: typeSize.height + 6)
            accentColor.setFill()
            UIBezierPath(roundedRect: pillRect, cornerRadius: 6).fill()
            typeStr.draw(at: CGPoint(x: 48, y: yOffset + 3))
            yOffset += 28

            // Meta info
            let dateStr = formatDate(inspection.started_at)
            let meta: [(String, String)] = [
                ("Date", dateStr),
                ("Inspector", inspectorName ?? "Unknown"),
                ("Status", inspection.status.replacingOccurrences(of: "_", with: " ").capitalized),
                ("Property", property?.name ?? "—"),
                ("Address", property?.address_line1 ?? "—")
            ]
            for (label, value) in meta {
                let nsLine = NSMutableAttributedString(string: "\(label):  ", attributes: boldBodyAttrs)
                nsLine.append(NSAttributedString(string: value, attributes: bodyAttrs))
                nsLine.draw(at: CGPoint(x: 40, y: yOffset))
                yOffset += 18
            }
            yOffset += 10

            // Divider
            drawDivider(at: yOffset, in: pageRect)
            yOffset += 16

            // ── Summary ─────────────────────────────────────────────────────────
            let total = anomalies.count + presentItems.count
            drawSectionHeader(title: "Summary", color: accentColor, rect: CGRect(x: 40, y: yOffset, width: pageRect.width - 80, height: 24))
            yOffset += 32

            let summaryLines: [(String, String, UIColor)] = [
                ("Total Items Checked", "\(total)", .label),
                ("Present", "\(presentItems.count)", .systemGreen),
                ("Issues Found", "\(anomalies.count)", anomalies.isEmpty ? .label : .systemRed)
            ]
            for (label, value, color) in summaryLines {
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: color]
                NSAttributedString(string: label, attributes: bodyAttrs).draw(at: CGPoint(x: 52, y: yOffset))
                NSAttributedString(string: value, attributes: attrs).draw(at: CGPoint(x: pageRect.width - 100, y: yOffset))
                yOffset += 18
            }
            yOffset += 16

            // ── Issues ──────────────────────────────────────────────────────────
            if !anomalies.isEmpty {
                yOffset = checkPageBreak(ctx: ctx, y: yOffset, pageRect: pageRect)
                drawSectionHeader(title: "⚠️  Issues Found (\(anomalies.count))", color: .systemRed, rect: CGRect(x: 40, y: yOffset, width: pageRect.width - 80, height: 24))
                yOffset += 32

                for item in anomalies {
                    yOffset = checkPageBreak(ctx: ctx, y: yOffset, pageRect: pageRect)
                    let statusColor: UIColor = item.inspectionItem.status == "missing" ? .systemOrange : .systemRed
                    let statusLabel = item.inspectionItem.status.capitalized

                    // Row background
                    UIColor.systemRed.withAlphaComponent(0.05).setFill()
                    UIBezierPath(roundedRect: CGRect(x: 40, y: yOffset - 4, width: pageRect.width - 80, height: 44), cornerRadius: 6).fill()

                    NSAttributedString(string: item.inventoryItem.name, attributes: boldBodyAttrs).draw(at: CGPoint(x: 52, y: yOffset))
                    NSAttributedString(string: item.room.name, attributes: secondaryAttrs).draw(at: CGPoint(x: 52, y: yOffset + 14))

                    let statusAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: statusColor]
                    NSAttributedString(string: statusLabel, attributes: statusAttrs).draw(at: CGPoint(x: pageRect.width - 120, y: yOffset + 7))

                    if let notes = item.inspectionItem.notes, !notes.isEmpty {
                        NSAttributedString(string: "Note: \(notes)", attributes: secondaryAttrs).draw(at: CGPoint(x: 52, y: yOffset + 28))
                        yOffset += 50
                    } else {
                        yOffset += 48
                    }
                }
                yOffset += 8
            }

            // ── Present Items ────────────────────────────────────────────────────
            if !presentItems.isEmpty {
                yOffset = checkPageBreak(ctx: ctx, y: yOffset, pageRect: pageRect)
                drawSectionHeader(title: "✓  All Clear (\(presentItems.count))", color: .systemGreen, rect: CGRect(x: 40, y: yOffset, width: pageRect.width - 80, height: 24))
                yOffset += 32

                // Group by room
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
                        let check = NSAttributedString(string: "✓  \(item.inventoryItem.name)", attributes: bodyAttrs)
                        check.draw(at: CGPoint(x: 52, y: yOffset))
                        yOffset += 16
                    }
                    yOffset += 4
                }
            }

            // ── Footer ──────────────────────────────────────────────────────────
            let footer = isWhiteLabel
                ? "Generated on \(dateStr)"
                : "Generated by Snapshots • \(dateStr)"
            NSAttributedString(string: footer, attributes: secondaryAttrs)
                .draw(at: CGPoint(x: 40, y: pageRect.height - 30))
        }
    }

    // MARK: - Helpers

    private static func drawSectionHeader(title: String, color: UIColor, rect: CGRect) {
        color.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 6).fill()
        NSAttributedString(string: title, attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.white
        ]).draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 5))
    }

    private static func drawDivider(at y: CGFloat, in rect: CGRect) {
        UIColor.lightGray.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 40, y: y))
        path.addLine(to: CGPoint(x: rect.width - 40, y: y))
        path.lineWidth = 0.5
        path.stroke()
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
        case "check-in": return "Check In"
        case "check-out": return "Check Out"
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
