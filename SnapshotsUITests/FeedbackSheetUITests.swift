import XCTest

final class FeedbackSheetUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSubmitButtonRequiresMinimumMessageLength() throws {
        let app = XCUIApplication()
        app.launchForScenario("feedback")

        let message = app.textViews["feedback.message"]
        let submit = app.buttons["feedback.submit"]

        XCTAssertTrue(message.waitForExistence(timeout: 2))
        XCTAssertFalse(submit.isEnabled)

        message.tap()
        message.typeText("This feedback is definitely long enough.")

        XCTAssertTrue(submit.isEnabled)
    }

    @MainActor
    func testFeedbackCategoryPickerExists() throws {
        let app = XCUIApplication()
        app.launchForScenario("feedback")

        XCTAssertTrue(app.buttons["feedback.category"].waitForExistence(timeout: 2))
    }
}
