import XCTest

final class CompleteProfileViewUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSaveButtonRequiresNonEmptyName() throws {
        let app = XCUIApplication()
        app.launchForScenario("completeProfile")

        let nameField = app.textFields["complete_profile.name"]
        let saveButton = app.buttons["complete_profile.save"]

        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        XCTAssertFalse(saveButton.isEnabled)

        nameField.tap()
        nameField.typeText("Jordan")

        XCTAssertTrue(saveButton.isEnabled)
    }
}
