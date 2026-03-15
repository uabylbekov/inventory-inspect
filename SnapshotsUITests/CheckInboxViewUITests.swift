import XCTest

final class CheckInboxViewUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCheckInboxScreenShowsEmailAndActions() throws {
        let app = XCUIApplication()
        app.launchForScenario("checkInbox")

        let message = app.identifiedElement("check_inbox.message")
        XCTAssertTrue(message.waitForExistence(timeout: 2))
        XCTAssertTrue(message.label.contains("tester@example.com"))

        XCTAssertTrue(app.identifiedElement("check_inbox.retry").waitForExistence(timeout: 2))
        XCTAssertTrue(app.identifiedElement("check_inbox.try_another").waitForExistence(timeout: 2))
    }
}
