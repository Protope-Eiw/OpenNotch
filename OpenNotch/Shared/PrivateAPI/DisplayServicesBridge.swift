import CoreGraphics
import Darwin
import IOKit

final class DisplayServicesBridge {
    static let shared = DisplayServicesBridge()

    typealias SetBrightnessFunction = @convention(c) (CGDirectDisplayID, Float) -> kern_return_t
    typealias GetBrightnessFunction = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> kern_return_t

    private let frameworkHandle: UnsafeMutableRawPointer?
    private let setBrightnessFunction: SetBrightnessFunction?
    private let getBrightnessFunction: GetBrightnessFunction?

    private init() {
        let frameworkPath = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        frameworkHandle = dlopen(frameworkPath, RTLD_NOW)

        if let symbol = frameworkHandle.flatMap({ dlsym($0, "DisplayServicesSetBrightness") }) {
            setBrightnessFunction = unsafeBitCast(symbol, to: SetBrightnessFunction.self)
        } else {
            setBrightnessFunction = nil
        }

        if let symbol = frameworkHandle.flatMap({ dlsym($0, "DisplayServicesGetBrightness") }) {
            getBrightnessFunction = unsafeBitCast(symbol, to: GetBrightnessFunction.self)
        } else {
            getBrightnessFunction = nil
        }
    }

    func setBrightness(displayID: CGDirectDisplayID, value: Float) -> kern_return_t? {
        setBrightnessFunction?(displayID, value)
    }

    func getBrightness(displayID: CGDirectDisplayID) -> (status: kern_return_t, value: Float)? {
        guard let getBrightnessFunction else {
            return nil
        }

        var value: Float = 0
        let status = getBrightnessFunction(displayID, &value)
        return (status, value)
    }

    deinit {
        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
    }
}
