import XCTest
@testable import OpenNotch

final class NotchScreenSelectionTests: XCTestCase {
    func testAutoReturnsEmptyArray() {
        let displayIDs = NotchScreenSelection.preferredDisplayIDs(
            for: NotchScreenSelectionPreferences(
                displayLocation: .auto,
                enabledDisplayUUIDs: []
            ),
            candidates: [
                NotchScreenSelectionCandidate(displayID: 11, displayUUID: "BUILTIN", isBuiltIn: true),
                NotchScreenSelectionCandidate(displayID: 42, displayUUID: "EXTERNAL", isBuiltIn: false)
            ],
            primaryDisplayID: 42
        )

        XCTAssertTrue(displayIDs.isEmpty)
    }

    func testManualReturnsEnabledDisplayIdentifiers() {
        let displayIDs = NotchScreenSelection.preferredDisplayIDs(
            for: NotchScreenSelectionPreferences(
                displayLocation: .manual,
                enabledDisplayUUIDs: ["EXTERNAL"]
            ),
            candidates: [
                NotchScreenSelectionCandidate(displayID: 11, displayUUID: "BUILTIN", isBuiltIn: true),
                NotchScreenSelectionCandidate(displayID: 42, displayUUID: "EXTERNAL", isBuiltIn: false)
            ],
            primaryDisplayID: 11
        )

        XCTAssertEqual(displayIDs, [42])
    }

    func testManualReturnsMultipleEnabledDisplayIdentifiers() {
        let displayIDs = NotchScreenSelection.preferredDisplayIDs(
            for: NotchScreenSelectionPreferences(
                displayLocation: .manual,
                enabledDisplayUUIDs: ["BUILTIN", "EXTERNAL"]
            ),
            candidates: [
                NotchScreenSelectionCandidate(displayID: 11, displayUUID: "BUILTIN", isBuiltIn: true),
                NotchScreenSelectionCandidate(displayID: 42, displayUUID: "EXTERNAL", isBuiltIn: false)
            ],
            primaryDisplayID: 11
        )

        XCTAssertEqual(displayIDs.sorted(), [11, 42])
    }

    func testManualFallsBackToPrimaryWhenNoEnabledUUIDsMatch() {
        let displayIDs = NotchScreenSelection.preferredDisplayIDs(
            for: NotchScreenSelectionPreferences(
                displayLocation: .manual,
                enabledDisplayUUIDs: ["MISSING"]
            ),
            candidates: [
                NotchScreenSelectionCandidate(displayID: 11, displayUUID: "BUILTIN", isBuiltIn: true),
                NotchScreenSelectionCandidate(displayID: 42, displayUUID: "EXTERNAL", isBuiltIn: false)
            ],
            primaryDisplayID: 42
        )

        XCTAssertEqual(displayIDs, [42])
    }

    func testManualFallsBackToFirstWhenPrimaryNotInCandidates() {
        let displayIDs = NotchScreenSelection.preferredDisplayIDs(
            for: NotchScreenSelectionPreferences(
                displayLocation: .manual,
                enabledDisplayUUIDs: ["MISSING"]
            ),
            candidates: [
                NotchScreenSelectionCandidate(displayID: 11, displayUUID: "BUILTIN", isBuiltIn: true)
            ],
            primaryDisplayID: 99
        )

        XCTAssertEqual(displayIDs, [11])
    }

    func testManualReturnsEmptyWhenNoCandidates() {
        let displayIDs = NotchScreenSelection.preferredDisplayIDs(
            for: NotchScreenSelectionPreferences(
                displayLocation: .manual,
                enabledDisplayUUIDs: []
            ),
            candidates: [],
            primaryDisplayID: nil
        )

        XCTAssertTrue(displayIDs.isEmpty)
    }
}
