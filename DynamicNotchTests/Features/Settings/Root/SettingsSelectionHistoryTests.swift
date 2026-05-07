import XCTest
@testable import DynamicNotch

final class SettingsSelectionHistoryTests: XCTestCase {
    func testRecordAppendsSelectionToHistory() {
        var history = SettingsRootViewModel.SelectionHistory(initialSelection: .general)

        history.record(.connectivity)

        XCTAssertEqual(history.currentSelection, .connectivity)
        XCTAssertTrue(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
    }

    func testRecordAfterGoingBackDropsForwardHistory() {
        var history = SettingsRootViewModel.SelectionHistory(initialSelection: .general)
        history.record(.connectivity)
        history.record(.system)

        XCTAssertEqual(history.goBack(), .connectivity)

        history.record(.media)

        XCTAssertEqual(history.currentSelection, .media)
        XCTAssertNil(history.goForward())
    }

    func testRecordSameSelectionDoesNotDuplicateHistory() {
        var history = SettingsRootViewModel.SelectionHistory(initialSelection: .general)

        history.record(.general)

        XCTAssertFalse(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
        XCTAssertNil(history.goBack())
    }

    func testBackAndForwardMoveAcrossRecordedSelections() {
        var history = SettingsRootViewModel.SelectionHistory(initialSelection: .general)
        history.record(.connectivity)
        history.record(.system)

        XCTAssertEqual(history.goBack(), .connectivity)
        XCTAssertEqual(history.goBack(), .general)
        XCTAssertNil(history.goBack())

        XCTAssertEqual(history.goForward(), .connectivity)
        XCTAssertEqual(history.goForward(), .system)
        XCTAssertNil(history.goForward())
    }
}
