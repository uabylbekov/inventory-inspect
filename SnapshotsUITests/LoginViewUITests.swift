import XCTest

final class LoginViewUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testInvalidEmailShowsValidationMessage() throws {
        let app = XCUIApplication()
        app.launchForScenario("login")

        let emailField = app.identifiedElement("login.email")
        XCTAssertTrue(emailField.waitForExistence(timeout: 2))

        emailField.tap()
        emailField.typeText("invalid-email")
        app.identifiedElement("login.continue").tap()

        XCTAssertTrue(app.identifiedElement("login.invalid_email").waitForExistence(timeout: 2))
    }

    @MainActor
    func testContinueButtonEnablesWhenEmailIsEntered() throws {
        let app = XCUIApplication()
        app.launchForScenario("login")

        let emailField = app.identifiedElement("login.email")
        let continueButton = app.identifiedElement("login.continue")

        XCTAssertTrue(emailField.waitForExistence(timeout: 2))
        XCTAssertFalse(continueButton.isEnabled)

        emailField.tap()
        emailField.typeText("tester@example.com")

        XCTAssertTrue(continueButton.isEnabled)
    }
}
