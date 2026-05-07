import XCTest

final class OpenNotchUITests: XCTestCase {
    @MainActor
    func testApplicationLaunchesInUITestMode() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
