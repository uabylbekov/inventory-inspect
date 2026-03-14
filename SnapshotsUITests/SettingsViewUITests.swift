import XCTest

final class SettingsViewUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSettingsScreenShowsPrimaryActions() throws {
        let app = XCUIApplication()
        app.launchForScenario("settings")

        XCTAssertTrue(app.buttons["settings.edit_profile"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["settings.feedback"].exists)
        XCTAssertTrue(app.buttons["settings.sign_out"].exists)
    }
}
