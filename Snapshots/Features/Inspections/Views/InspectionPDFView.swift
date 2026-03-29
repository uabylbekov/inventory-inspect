import SwiftUI

struct InspectionPDFView: View {
    let property: PropertyModel
    let inspection: InspectionModel
    let inspectorName: String?
    let anomalies: [ReportItem]
    let resolvedItems: [ReportItem]
    let presentItems: [ReportItem]
    var logoImage: PlatformImage? = nil
    var evidenceImages: [UUID: PlatformImage] = [:]
    var isWhiteLabel: Bool = false
    var businessDetailsLines: [String] = []

    private let canvas = Color.white
    private let divider = Color(red: 0.90, green: 0.91, blue: 0.93)
    private let primaryText = Color(red: 0.10, green: 0.11, blue: 0.13)
    private let secondaryText = Color(red: 0.34, green: 0.37, blue: 0.43)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
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
        .padding(34)
        .frame(width: 612, alignment: .topLeading)
        .background(canvas)
        .foregroundColor(primaryText)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "pdf.report.title").uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .default))
                        .foregroundColor(secondaryText)
                        .tracking(1.1)

                    Text(property.name)
                        .font(.system(size: 29, weight: .semibold, design: .serif))
                        .foregroundColor(primaryText)

                    Text(property.address_line1 ?? String(localized: "pdf.address_missing"))
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(secondaryText)

                    Text(AppFormatter.formatInspectionType(inspection.inspection_type))
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(secondaryText)
                }

                Spacer()

                if let logo = logoImage {
                    Image(platformImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 82, height: 82)
                }
            }

            if isWhiteLabel, !businessDetailsLines.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(businessDetailsLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 10.5, weight: .regular, design: .default))
                            .foregroundColor(secondaryText)
                    }
                }
            }

            Rectangle()
                .fill(divider)
                .frame(height: 1)

            HStack(alignment: .top, spacing: 16) {
                metaColumn(label: String(localized: "pdf.meta.date"), value: AppFormatter.formatDate(inspection.started_at))
                metaColumn(label: String(localized: "pdf.meta.inspector"), value: inspectorName ?? String(localized: "common.unknown"))
                metaColumn(label: String(localized: "pdf.meta.status"), value: inspectionStatusLabel)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 0) {
            summaryMetric(title: String(localized: "pdf.summary.anomalies"), count: anomalies.count)
            summaryDivider
            summaryMetric(title: String(localized: "pdf.summary.resolved"), count: resolvedItems.count)
            summaryDivider
            summaryMetric(title: String(localized: "pdf.summary.present"), count: presentItems.count)
        }
        .padding(.vertical, 4)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(divider)
            .frame(width: 1)
            .padding(.vertical, 10)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(divider)
                .frame(height: 1)

            Text(footerText)
                .font(.system(size: 9.5, weight: .regular, design: .default))
                .foregroundColor(secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, 4)
    }

    private func metaColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .default))
                .foregroundColor(secondaryText)
                .tracking(0.8)

            Text(value)
                .font(.system(size: 12.5, weight: .medium, design: .default))
                .foregroundColor(primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryMetric(title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(count)")
                .font(.system(size: 25, weight: .semibold, design: .serif))
                .foregroundColor(primaryText)

            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold, design: .default))
                .foregroundColor(secondaryText)
                .tracking(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }

    private func narrativeBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .default))
                .foregroundColor(secondaryText)
                .tracking(0.7)

            Text(body)
                .font(.system(size: 11.5, weight: .regular, design: .default))
                .foregroundColor(primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionBlock(title: String, subtitle: String, items: [ReportItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundColor(primaryText)

                Text(subtitle)
                    .font(.system(size: 10.5, weight: .regular, design: .default))
                    .foregroundColor(secondaryText)
            }

            Rectangle()
                .fill(divider)
                .frame(height: 1)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                pdfItemRow(item: item)
                if index < items.count - 1 {
                    Rectangle()
                        .fill(divider)
                        .frame(height: 1)
                }
            }
        }
    }

    private func pdfItemRow(item: ReportItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.inventoryItem.name)
                    .font(.system(size: 13.5, weight: .semibold, design: .default))
                    .foregroundColor(primaryText)

                Spacer()

                statusTag(for: item.inspectionItem.status, previousStatus: item.inspectionItem.previous_status)
            }

            Text(item.room.name)
                .font(.system(size: 10.5, weight: .regular, design: .default))
                .foregroundColor(secondaryText)

            if let notes = item.inspectionItem.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundColor(primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            evidenceThumbnail(for: item)
        }
        .padding(.vertical, 4)
    }

    private func statusTag(for status: String, previousStatus: String? = nil) -> some View {
        let tint = statusColor(status)
        return Text(statusLabel(status, previousStatus: previousStatus).uppercased())
            .font(.system(size: 8.5, weight: .semibold, design: .default))
            .foregroundColor(tint)
            .tracking(0.5)
    }

    @ViewBuilder
    private func evidenceThumbnail(for item: ReportItem) -> some View {
        if let image = evidenceImages[item.inspectionItem.id] {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "pdf.photo_evidence").uppercased())
                    .font(.system(size: 8.5, weight: .semibold, design: .default))
                    .foregroundColor(secondaryText)
                    .tracking(0.5)

                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260, maxHeight: 160, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let imageUrl = item.inspectionItem.image_url, !imageUrl.isEmpty {
            Text("pdf.photo_reference_not_embedded")
                .font(.system(size: 9, weight: .semibold, design: .default))
                .foregroundColor(secondaryText)
                .tracking(0.5)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            return Color(red: 0.74, green: 0.22, blue: 0.22)
        case "missing":
            return Color(red: 0.70, green: 0.45, blue: 0.16)
        case "resolved":
            return Color(red: 0.12, green: 0.38, blue: 0.65)
        case "present":
            return Color(red: 0.20, green: 0.48, blue: 0.30)
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
