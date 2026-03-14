import Testing
@testable import Snapshots

@MainActor
@Suite("Team And Feedback Validation")
struct TeamAndFeedbackValidationTests {
    @Test("ManageTeamViewModel trims email input for validation")
    func manageTeamEmailValidation() {
        let viewModel = ManageTeamViewModel(propertyId: UUID())
        viewModel.newMemberEmail = "  teammate@example.com  "

        #expect(viewModel.isValidEmail)
        #expect(!viewModel.isInviteDisabled)

        viewModel.isSaving = true
        #expect(viewModel.isInviteDisabled)
    }

    @Test("ManageTeamViewModel rejects obviously invalid email addresses")
    func manageTeamRejectsInvalidEmail() {
        let viewModel = ManageTeamViewModel(propertyId: UUID())
        viewModel.newMemberEmail = "invalid-email"

        #expect(!viewModel.isValidEmail)
        #expect(viewModel.isInviteDisabled)
    }

    @Test("FeedbackViewModel trims messages and enforces minimum length")
    func feedbackValidation() {
        let viewModel = FeedbackViewModel(userName: "Jordan", personalTier: "free")
        viewModel.message = "   too short  "

        #expect(viewModel.trimmedMessage == "too short")
        #expect(viewModel.isSubmitDisabled)

        viewModel.message = "   This feedback is long enough.  "
        #expect(viewModel.trimmedMessage == "This feedback is long enough.")
        #expect(!viewModel.isSubmitDisabled)

        viewModel.isSubmitting = true
        #expect(viewModel.isSubmitDisabled)
    }

    @Test("Feedback categories expose stable raw values and Discord labels")
    func feedbackCategoryMetadata() {
        #expect(FeedbackViewModel.Category.bug.id == "bug")
        #expect(FeedbackViewModel.Category.featureRequest.rawValue == "feature_request")
        #expect(FeedbackViewModel.Category.billing.discordLabel == "Billing")
        #expect(FeedbackViewModel.Category.other.discordLabel == "Other")
    }
}
