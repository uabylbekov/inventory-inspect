import Foundation
import SwiftUI
import Supabase

@Observable @MainActor
final class FeedbackViewModel {
    enum Category: String, CaseIterable, Identifiable, Codable, Hashable {
        case bug = "bug"
        case featureRequest = "feature_request"
        case billing = "billing"
        case usability = "usability"
        case other = "other"

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .bug: return "feedback.category.bug"
            case .featureRequest: return "feedback.category.feature_request"
            case .billing: return "feedback.category.billing"
            case .usability: return "feedback.category.usability"
            case .other: return "feedback.category.other"
            }
        }

        var discordLabel: String {
            switch self {
            case .bug: return "Bug Report"
            case .featureRequest: return "Feature Request"
            case .billing: return "Billing"
            case .usability: return "Usability"
            case .other: return "Other"
            }
        }
    }

    var selectedCategory: Category = .bug
    var message = ""
    var isSubmitting = false
    var errorMessage: String?
    var didSubmit = false

    private let userName: String
    private let personalTier: String

    init(userName: String, personalTier: String) {
        self.userName = userName
        self.personalTier = personalTier
    }

    var isSubmitDisabled: Bool {
        trimmedMessage.count < 10 || isSubmitting
    }

    var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func submit() async {
        guard !isSubmitDisabled else { return }

        struct FeedbackPayload: Encodable {
            let category: String
            let category_label: String
            let message: String
            let user_name: String
            let personal_tier: String
            let app_version: String
            let build_number: String
            let ios_version: String
            let locale_identifier: String
        }

        struct FeedbackResponse: Decodable {
            let success: Bool?
            let error: String?
        }

        isSubmitting = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.session
            let payload = FeedbackPayload(
                category: selectedCategory.rawValue,
                category_label: selectedCategory.discordLabel,
                message: trimmedMessage,
                user_name: userName,
                personal_tier: personalTier,
                app_version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                build_number: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2026.3",
                ios_version: platformSystemVersionString(),
                locale_identifier: Locale.current.identifier
            )

            let response: FeedbackResponse = try await supabase.functions
                .invoke(
                    "send-feedback",
                    options: .init(
                        headers: [
                            "Authorization": "Bearer \(session.accessToken)"
                        ],
                        body: payload
                    )
                )

            if let error = response.error {
                errorMessage = error
                isSubmitting = false
                return
            }

            didSubmit = true
            message = ""
            isSubmitting = false
        } catch is CancellationError {
            isSubmitting = false
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
