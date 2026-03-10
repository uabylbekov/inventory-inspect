import Foundation

enum ExportFileNameBuilder {
    nonisolated static func pdfFileName(prefix: String, parts: [String]) -> String {
        let sanitizedParts = parts
            .map(sanitize)
            .filter { !$0.isEmpty }

        let timestamp = makeTimestamp()
        let nameBody = ([sanitize(prefix)] + sanitizedParts)
            .filter { !$0.isEmpty }
            .joined(separator: "_")

        return "\(nameBody)_\(timestamp).pdf"
    }

    nonisolated private static func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_"))
        let scalars = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let collapsed = String(scalars)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return collapsed
    }

    nonisolated private static func makeTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}
