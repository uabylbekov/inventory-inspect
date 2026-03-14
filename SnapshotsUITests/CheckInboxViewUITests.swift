import XCTest

final class CheckInboxViewUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCheckInboxScreenShowsEmailAndActions() throws {
        let app = XCUIApplication()
        app.launchForScenario("checkInbox")

        let message = app.staticTexts["check_inbox.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 2))
        XCTAssertTrue(message.label.contains("tester@example.com"))

        XCTAssertTrue(app.buttons["check_inbox.retry"].exists)
        XCTAssertTrue(app.buttons["check_inbox.try_another"].exists)
    }
}
