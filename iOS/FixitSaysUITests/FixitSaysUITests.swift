import XCTest

final class FixitSaysUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func testLaunchShowsDiagnoseFlow() {
        let app = XCUIApplication()
        app.launchEnvironment["FIXITSAYS_NO_SK"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["diagnose"].waitForExistence(timeout: 8))
        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
    }
}
