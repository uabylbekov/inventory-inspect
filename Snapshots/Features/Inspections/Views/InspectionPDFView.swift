import SwiftUI

struct InspectionPDFView: View {
    let property: PropertyModel
    let inspection: InspectionModel
    let inspectorName: String?
    let anomalies: [ReportItem]
    let resolvedItems: [ReportItem]
    let presentItems: [ReportItem]
    var logoImage: PlatformImage? = nil
    var isWhiteLabel: Bool = false
    var businessDetailsLines: [String] = []

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

            if let notes = inspection.notes, !notes.isEmpty {
                narrativeBlock(title: String(localized: "pdf.meta.notes"), body: notes)
            }

            if !anomalies.isEmpty {
                sectionBlock(
                    title: String(localized: "pdf.section.anomalies"),
                    subtitle: "\(anomalies.count) items require attention",
                    items: anomalies
                )
            }

            if !resolvedItems.isEmpty {
                sectionBlock(
                    title: String(localized: "pdf.section.resolved"),
                    subtitle: "\(resolvedItems.count) issues were fixed",
                    items: resolvedItems
                )
            }

            if !presentItems.isEmpty {
                sectionBlock(
                    title: String(localized: "report.present_intact"),
                    subtitle: "\(presentItems.count) items were present and intact",
                    items: presentItems
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
                    Text(String(localized: "pdf.report.title"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accent)
                        .tracking(0.8)

                    Text(property.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(primaryText)

                    Text(property.address_line1 ?? String(localized: "pdf.address_missing"))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(secondaryText)

                    Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(secondaryText)
                }

                Spacer()

                if let logo = logoImage {
                    Image(platformImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                }
            }

            if isWhiteLabel, !businessDetailsLines.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(businessDetailsLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(secondaryText)
                    }
                }
            }

            HStack(spacing: 12) {
                metaCard(label: String(localized: "pdf.meta.date"), value: AppFormatter.formatDate(inspection.started_at))
                metaCard(label: String(localized: "pdf.meta.inspector"), value: inspectorName ?? String(localized: "common.unknown"))
                metaCard(label: String(localized: "pdf.meta.status"), value: inspectionStatusLabel)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: String(localized: "pdf.summary.anomalies"),
                count: anomalies.count,
                color: .red
            )
            summaryCard(
                title: String(localized: "pdf.summary.resolved"),
                count: resolvedItems.count,
                color: .blue
            )
            summaryCard(
                title: String(localized: "pdf.summary.present"),
                count: presentItems.count,
                color: .green
            )
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Divider()
                .overlay(border)

            Text(footerText)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, 8)
    }

    private func metaCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(secondaryText)
                .tracking(0.4)

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
                .overlay(
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                )

            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(primaryText)

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

    private func narrativeBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(primaryText)

            Text(body)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sectionBlock(title: String, subtitle: String, items: [ReportItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(primaryText)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(secondaryText)
            }

            ForEach(items) { item in
                pdfItemRow(item: item)
            }
        }
    }

    private func pdfItemRow(item: ReportItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(statusColor(item.inspectionItem.status))
                    .frame(width: 6)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.inventoryItem.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(primaryText)
                            Text(item.room.name)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(secondaryText)
                        }

                        Spacer()

                        statusChip(for: item.inspectionItem.status, previousStatus: item.inspectionItem.previous_status)
                    }

                    if let notes = item.inspectionItem.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusChip(for status: String, previousStatus: String? = nil) -> some View {
        Text(statusLabel(status, previousStatus: previousStatus))
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(statusColor(status))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(statusColor(status).opacity(0.12))
            .clipShape(Capsule())
    }

    private func statusLabel(_ status: String, previousStatus: String? = nil) -> String {
        if status == "resolved", let previousStatus, isResolvableIssue(previousStatus) {
            return String.localizedStringWithFormat(
                NSLocalizedString("pdf.status.resolved_from", comment: ""),
                statusLabel(previousStatus)
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

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "damaged":
            return .red
        case "missing":
            return .orange
        case "resolved":
            return .blue
        case "present":
            return .green
        default:
            return secondaryText
        }
    }

    private var inspectionStatusLabel: String {
        inspection.status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var footerText: String {
        let date = AppFormatter.formatDate(inspection.completed_at ?? inspection.started_at)
        if isWhiteLabel {
            return String.localizedStringWithFormat(
                NSLocalizedString("comparison_pdf.generated_on", comment: ""),
                date
            )
        }
        return String.localizedStringWithFormat(
            NSLocalizedString("pdf.footer_with_date", comment: ""),
            date
        )
    }

    private func isResolvableIssue(_ status: String) -> Bool {
        status == "missing" || status == "damaged"
    }
}
