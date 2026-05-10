//
//  extension+NSScreen.swift
//  OpenNotch
//
//  Created by Евгений Петрукович on 3/12/26.
//

import SwiftUI

struct NotchScreenSelectionPreferences: Equatable {
    let displayLocation: NotchDisplayLocation
    let enabledDisplayUUIDs: Set<String>
}

struct NotchDisplayOption: Identifiable, Hashable {
    let displayUUID: String
    let displayID: CGDirectDisplayID?
    let name: String
    let isBuiltIn: Bool
    let isMain: Bool
    let isAvailable: Bool
    fileprivate let frame: CGRect?

    var id: String {
        displayUUID
    }

    var symbolName: String {
        if !isAvailable {
            return "display.trianglebadge.exclamationmark"
        }

        if isBuiltIn {
            return "macbook.gen2"
        }

        if isMain {
            return "desktopcomputer.and.macbook"
        }

        return "display"
    }

    static func unavailable(displayUUID: String, name: String) -> NotchDisplayOption {
        NotchDisplayOption(
            displayUUID: displayUUID,
            displayID: nil,
            name: name,
            isBuiltIn: false,
            isMain: false,
            isAvailable: false,
            frame: nil
        )
    }
}

struct NotchScreenSelectionCandidate: Equatable {
    let displayID: CGDirectDisplayID
    let displayUUID: String
    let isBuiltIn: Bool
}

enum NotchScreenSelection {
    static func preferredDisplayIDs(for preferences: NotchScreenSelectionPreferences, candidates: [NotchScreenSelectionCandidate], primaryDisplayID: CGDirectDisplayID?) -> [CGDirectDisplayID] {
        switch preferences.displayLocation {
        case .auto:
            return []

        case .manual:
            let matching = candidates.filter { preferences.enabledDisplayUUIDs.contains($0.displayUUID.uppercased()) }
            if !matching.isEmpty {
                return matching.map(\.displayID)
            }

            if let primaryDisplayID, candidates.contains(where: { $0.displayID == primaryDisplayID }) {
                return [primaryDisplayID]
            }

            return candidates.first.map { [$0.displayID] } ?? []
        }
    }
}

extension NSScreen {
    static var screenWithMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }

    static var preferredLockScreen: NSScreen? {
        screens.first(where: \.isBuiltInDisplay) ?? main ?? screenWithMouse ?? screens.first
    }

    static func availableNotchDisplays(primaryDisplayID: CGDirectDisplayID? = CGMainDisplayID()) -> [NotchDisplayOption] {
        screens
            .compactMap { screen in
                guard let displayID = screen.displayID,
                      let displayUUID = screen.displayUUIDString else {
                    return nil
                }

                return NotchDisplayOption(
                    displayUUID: displayUUID,
                    displayID: displayID,
                    name: screen.localizedName,
                    isBuiltIn: screen.isBuiltInDisplay,
                    isMain: displayID == primaryDisplayID,
                    isAvailable: true,
                    frame: screen.frame
                )
            }
            .sorted(by: sortDisplayOptions)
    }

    static func preferredNotchScreens(for preferences: NotchScreenSelectionPreferences) -> [NSScreen] {
        switch preferences.displayLocation {
        case .auto:
            return screenWithMouse.map { [$0] } ?? []

        case .manual:
            let selectedIDs = NotchScreenSelection.preferredDisplayIDs(
                for: preferences,
                candidates: notchScreenSelectionCandidates,
                primaryDisplayID: CGMainDisplayID()
            )
            let screens = selectedIDs.compactMap { screen(matchingDisplayID: $0) }
            if !screens.isEmpty {
                return screens
            }
            return screens.first.map { [$0] } ?? Self.screens.first.map { [$0] } ?? []
        }
    }

    static func preferredNotchScreens(for settings: any NotchSettingsProviding) -> [NSScreen] {
        preferredNotchScreens(for: settings.screenSelectionPreferences)
    }

    static func preferredNotchScreens(for location: NotchDisplayLocation) -> [NSScreen] {
        preferredNotchScreens(
            for: NotchScreenSelectionPreferences(
                displayLocation: location,
                enabledDisplayUUIDs: []
            )
        )
    }

    static func preferredNotchScreen(for preferences: NotchScreenSelectionPreferences) -> NSScreen? {
        preferredNotchScreens(for: preferences).first
    }

    static func preferredNotchScreen(for settings: any NotchSettingsProviding) -> NSScreen? {
        preferredNotchScreens(for: settings).first
    }

    static func preferredNotchScreen(for location: NotchDisplayLocation) -> NSScreen? {
        preferredNotchScreens(for: location).first
    }

    static func preferredNotchDisplay(
        for preferences: NotchScreenSelectionPreferences
    ) -> NotchDisplayOption? {
        let availableDisplays = availableNotchDisplays()
        let displayIDs = NotchScreenSelection.preferredDisplayIDs(
            for: preferences,
            candidates: notchScreenSelectionCandidates,
            primaryDisplayID: CGMainDisplayID()
        )

        if let firstID = displayIDs.first,
           let selectedDisplay = availableDisplays.first(where: { $0.displayID == firstID }) {
            return selectedDisplay
        }

        guard case .manual = preferences.displayLocation else {
            return availableDisplays.first
        }

        return nil
    }

    static func metrics(for screen: NSScreen) -> NotchScreenMetrics? {
        (
            width: screen.frame.width,
            topInset: screen.safeAreaInsets.top,
            notchSize: screen.notchSize
        )
    }

    static func metrics(for preferences: NotchScreenSelectionPreferences) -> NotchScreenMetrics? {
        guard let screen = preferredNotchScreen(for: preferences) else {
            return nil
        }
        return metrics(for: screen)
    }

    static func metrics(for settings: any NotchSettingsProviding) -> NotchScreenMetrics? {
        metrics(for: settings.screenSelectionPreferences)
    }

    static func metrics(for location: NotchDisplayLocation) -> NotchScreenMetrics? {
        metrics(
            for: NotchScreenSelectionPreferences(
                displayLocation: location,
                enabledDisplayUUIDs: []
            )
        )
    }

    private static var notchScreenSelectionCandidates: [NotchScreenSelectionCandidate] {
        screens.compactMap { screen in
            guard let displayID = screen.displayID,
                  let displayUUID = screen.displayUUIDString else {
                return nil
            }

            return NotchScreenSelectionCandidate(
                displayID: displayID,
                displayUUID: displayUUID,
                isBuiltIn: screen.isBuiltInDisplay
            )
        }
    }

    private static func screen(matchingDisplayID displayID: CGDirectDisplayID) -> NSScreen? {
        screens.first { $0.displayID == displayID }
    }

    nonisolated private static func sortDisplayOptions(lhs: NotchDisplayOption, rhs: NotchDisplayOption) -> Bool {
        if lhs.isMain != rhs.isMain {
            return lhs.isMain && !rhs.isMain
        }

        if lhs.isBuiltIn != rhs.isBuiltIn {
            return lhs.isBuiltIn && !rhs.isBuiltIn
        }

        let lhsFrame = lhs.frame ?? .zero
        let rhsFrame = rhs.frame ?? .zero

        if lhsFrame.minX != rhsFrame.minX {
            return lhsFrame.minX < rhsFrame.minX
        }

        if lhsFrame.minY != rhsFrame.minY {
            return lhsFrame.minY < rhsFrame.minY
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    var displayUUIDString: String? {
        guard let displayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return nil
        }

        return (CFUUIDCreateString(nil, uuid) as String).uppercased()
    }

    var isBuiltInDisplay: Bool {
        if notchSize != nil { return true }
        let hasAnyNotchedScreen = Self.screens.contains { $0.notchSize != nil }
        if hasAnyNotchedScreen {
            return false
        }
        guard let displayID else { return false }
        return CGDisplayIsBuiltin(displayID) != 0
    }

    var notchSize: CGSize? {
        if #available(macOS 12.0, *) {
            guard let leftArea = auxiliaryTopLeftArea,
                  let rightArea = auxiliaryTopRightArea else {
                return nil
            }

            let notchWidth = frame.width - (leftArea.width + rightArea.width)
            let notchHeight = leftArea.height

            guard notchWidth > 0 else { return nil }

            return CGSize(width: notchWidth, height: notchHeight)
        }

        return nil
    }
}
