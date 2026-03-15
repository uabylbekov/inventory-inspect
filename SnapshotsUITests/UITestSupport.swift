import XCTest

extension XCUIApplication {
    func launchForScenario(_ scenario: String) {
        launchEnvironment["SNAPSHOTS_UI_TEST_SCENARIO"] = scenario
        launch()
    }

    func identifiedElement(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier]
    }
}
