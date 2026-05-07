import Foundation
import IOKit

struct MacSystemInfo {
    var modelName: String = "Mac"
    var chipName: String = "–"
    var ramText: String = "–"
    var serialNumber: String = "–"
    var macOSVersion: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }()

    static func load() async -> MacSystemInfo {
        var info = MacSystemInfo()
        info.serialNumber = readSerial()
        info.ramText = readRAM()

        if let hw = await readHardwareProfiler() {
            if let name = hw["machine_name"] as? String { info.modelName = name }
            if let chip = hw["cpu_type"] as? String     { info.chipName  = chip }
            if let mem  = hw["physical_memory"] as? String { info.ramText = mem }
        }
        return info
    }

    private static func readHardwareProfiler() async -> [String: Any]? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
                process.arguments = ["SPHardwareDataType", "-json"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let hw = (json["SPHardwareDataType"] as? [[String: Any]])?.first {
                        continuation.resume(returning: hw)
                        return
                    }
                } catch {}
                continuation.resume(returning: nil)
            }
        }
    }

    private static func readRAM() -> String {
        var size: Int64 = 0
        var len = MemoryLayout<Int64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return "\(Int(Double(size) / 1_073_741_824)) GB"
    }

    private static func readSerial() -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                 IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        guard service != 0 else { return "–" }
        return IORegistryEntryCreateCFProperty(
            service, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String ?? "–"
    }
}
