import CoreGraphics
import Foundation
import IOKit
import IOKit.graphics

final class SystemDisplayBrightnessService {
    private let displayServicesBridge: DisplayServicesBridge

    init(displayServicesBridge: DisplayServicesBridge = .shared) {
        self.displayServicesBridge = displayServicesBridge
    }

    func adjust(direction: MediaKeyDirection, granularity: MediaKeyGranularity) -> Int {
        let delta = stepSize(for: granularity) * (direction == .increase ? 1 : -1)
        let displayID = targetDisplayID()
        let brightness = brightness(for: displayID) ?? 0.5
        return setBrightness(brightness + delta, displayID: displayID)
    }

    @discardableResult
    func setBrightness(_ value: Float) -> Int {
        setBrightness(value, displayID: targetDisplayID())
    }

    @discardableResult
    private func setBrightness(_ value: Float, displayID: CGDirectDisplayID) -> Int {
        let clampedValue = max(0, min(1, value))

        if let result = displayServicesBridge.setBrightness(displayID: displayID, value: clampedValue),
           result == kIOReturnSuccess {
            return percentValue(for: clampedValue)
        }

        guard let service = matchingDisplayService(for: displayID) else {
            return percentValue(for: currentBrightness)
        }

        let status = IODisplaySetFloatParameter(
            service,
            0,
            kIODisplayBrightnessKey as CFString,
            clampedValue
        )
        IOObjectRelease(service)

        if status != kIOReturnSuccess {
            NSLog("Failed to set display brightness: \(status)")
        }

        return percentValue(for: currentBrightness)
    }

    var currentBrightness: Float {
        brightness(for: targetDisplayID()) ?? 0.5
    }

    private func brightness(for displayID: CGDirectDisplayID) -> Float? {
        if let brightnessResult = displayServicesBridge.getBrightness(displayID: displayID),
           brightnessResult.status == kIOReturnSuccess {
            return max(0, min(1, brightnessResult.value))
        }

        guard let service = matchingDisplayService(for: displayID) else {
            return nil
        }

        var brightness: Float = 0.5
        let status = IODisplayGetFloatParameter(
            service,
            0,
            kIODisplayBrightnessKey as CFString,
            &brightness
        )
        IOObjectRelease(service)

        guard status == kIOReturnSuccess else {
            return nil
        }

        return max(0, min(1, brightness))
    }

    private func targetDisplayID() -> CGDirectDisplayID {
        let displays = onlineDisplayIDs()

        guard !displays.isEmpty else {
            return CGMainDisplayID()
        }

        let preferredDisplays = orderedPreferredDisplayIDs(from: displays)
        return preferredDisplays.first(where: { brightness(for: $0) != nil })
            ?? preferredDisplays.first(where: { CGDisplayIsBuiltin($0) != 0 })
            ?? CGMainDisplayID()
    }

    private func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &displayCount)

        guard displayCount > 0 else {
            return []
        }

        var displays = Array(repeating: CGDirectDisplayID(), count: Int(displayCount))
        let status = CGGetOnlineDisplayList(displayCount, &displays, &displayCount)

        guard status == .success else {
            return []
        }

        return Array(displays.prefix(Int(displayCount)))
    }

    private func orderedPreferredDisplayIDs(from displays: [CGDirectDisplayID]) -> [CGDirectDisplayID] {
        var ordered: [CGDirectDisplayID] = []

        if let cursorDisplay = displayContainingCursor(in: displays) {
            ordered.append(cursorDisplay)
        }

        ordered.append(CGMainDisplayID())

        if let builtinDisplay = displays.first(where: { CGDisplayIsBuiltin($0) != 0 }) {
            ordered.append(builtinDisplay)
        }

        ordered.append(contentsOf: displays)
        return ordered.reduce(into: []) { result, displayID in
            guard displays.contains(displayID), !result.contains(displayID) else {
                return
            }

            result.append(displayID)
        }
    }

    private func displayContainingCursor(in displays: [CGDirectDisplayID]) -> CGDirectDisplayID? {
        guard let cursorLocation = CGEvent(source: nil)?.location else {
            return nil
        }

        return displays.first { displayID in
            CGDisplayBounds(displayID).contains(cursorLocation)
        }
    }

    private func matchingDisplayService(for displayID: CGDirectDisplayID) -> io_service_t? {
        let vendorID = CGDisplayVendorNumber(displayID)
        let productID = CGDisplayModelNumber(displayID)
        let serialNumber = CGDisplaySerialNumber(displayID)

        var iterator = io_iterator_t()
        let status = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )

        guard status == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            guard let infoDictionary = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as? [String: Any] else {
                IOObjectRelease(service)
                continue
            }

            let serviceVendorID = infoDictionary[kDisplayVendorID as String] as? UInt32
            let serviceProductID = infoDictionary[kDisplayProductID as String] as? UInt32
            let serviceSerialNumber = infoDictionary[kDisplaySerialNumber as String] as? UInt32

            let vendorMatches = serviceVendorID == vendorID
            let productMatches = serviceProductID == productID
            let serialMatches = serialNumber == 0 || serviceSerialNumber == serialNumber

            if vendorMatches && productMatches && serialMatches {
                return service
            }

            IOObjectRelease(service)
        }

        return nil
    }

    private func stepSize(for granularity: MediaKeyGranularity) -> Float {
        switch granularity {
        case .standard:
            return 1.0 / 16.0
        case .fine:
            return 1.0 / 64.0
        }
    }

    private func percentValue(for scalar: Float) -> Int {
        Int((max(0, min(1, scalar)) * 100).rounded())
    }
}
