import XCTest

final class SettingsViewUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSettingsScreenShowsPrimaryActions() throws {
        let app = XCUIApplication()
        app.launchForScenario("settings")

        XCTAssertTrue(app.identifiedElement("settings.edit_profile").waitForExistence(timeout: 2))
        XCTAssertTrue(app.identifiedElement("settings.feedback").waitForExistence(timeout: 2))
        XCTAssertTrue(app.identifiedElement("settings.sign_out").waitForExistence(timeout: 2))
    }
}
