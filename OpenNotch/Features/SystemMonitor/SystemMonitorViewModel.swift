import Combine
import Foundation
import Darwin
import IOKit.ps

@MainActor
final class SystemMonitorViewModel: ObservableObject {
    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var memoryUsage: Double = 0
    @Published private(set) var uploadSpeed: Double = 0
    @Published private(set) var downloadSpeed: Double = 0
    @Published private(set) var batteryLevel: Int = 0
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var diskUsage: Double = 0
    @Published private(set) var diskUsedText: String = "–"
    @Published private(set) var diskTotalText: String = "–"

    @Published private(set) var cpuHistory: [SWLineChart<String>.DataPoint] = []
    @Published private(set) var memoryHistory: [SWAreaChart<String>.DataPoint] = []

    private var cpuNetTask: Task<Void, Never>?
    private var memTask: Task<Void, Never>?
    private var diskTask: Task<Void, Never>?
    private var previousNetworkStats: NetworkStats?
    private let maxHistory = 60
    private var powerSourceRunLoopSource: CFRunLoopSource?

    private struct NetworkStats {
        var bytesSent: UInt64
        var bytesReceived: UInt64
        var timestamp: Date
    }

    func startMonitoring() {
        guard cpuNetTask == nil else { return }

        cpuNetTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshCPU()
                await self?.refreshNetwork()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        memTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshMemory()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        diskTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshDisk()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }

        setupPowerNotification()
        refreshDisk()
    }

    func stopMonitoring() {
        cpuNetTask?.cancel()
        cpuNetTask = nil
        memTask?.cancel()
        memTask = nil
        diskTask?.cancel()
        diskTask = nil

        if let source = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            powerSourceRunLoopSource = nil
        }
    }

    private func setupPowerNotification() {
        let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let unmanaged = Unmanaged<SystemMonitorViewModel>.fromOpaque(context)
            unmanaged.takeUnretainedValue().readBattery()
        }, Unmanaged.passUnretained(self).toOpaque()).takeRetainedValue()

        powerSourceRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        readBattery()
    }

    private func refreshCPU() {
        let cpu = readCPUUsage()
        cpuUsage = cpu

        let now = Date()
        cpuHistory.append(.init(date: now, value: cpu, category: "CPU"))
        if cpuHistory.count > maxHistory { cpuHistory.removeFirst(cpuHistory.count - maxHistory) }
    }

    private func refreshMemory() {
        let mem = readMemoryUsage()
        memoryUsage = mem

        let now = Date()
        memoryHistory.append(.init(date: now, value: mem, category: "MEM"))
        if memoryHistory.count > maxHistory { memoryHistory.removeFirst(memoryHistory.count - maxHistory) }
    }

    private func refreshNetwork() {
        updateNetworkSpeed()
    }

    private func refreshDisk() {
        updateDiskUsage()
    }

    private func readBattery() {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(info, source)
                    .takeUnretainedValue() as? [String: Any] else { continue }
            batteryLevel = desc[kIOPSCurrentCapacityKey] as? Int ?? batteryLevel
            isCharging   = desc[kIOPSIsChargingKey]      as? Bool ?? isCharging
            return
        }
    }

    private func readCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUsU: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUsU)
        guard result == KERN_SUCCESS, let cpuInfo else { return cpuUsage }

        var totalUsage = 0.0
        for i in 0..<Int(numCPUs) {
            let base = Int(CPU_STATE_MAX) * i
            let user   = Double(cpuInfo[base + Int(CPU_STATE_USER)])
            let system = Double(cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            let nice   = Double(cpuInfo[base + Int(CPU_STATE_NICE)])
            let idle   = Double(cpuInfo[base + Int(CPU_STATE_IDLE)])
            let total  = user + system + nice + idle
            totalUsage += total > 0 ? (user + system + nice) / total : 0
        }

        vm_deallocate(
            mach_task_self_,
            vm_address_t(bitPattern: cpuInfo),
            vm_size_t(numCPUsU) * vm_size_t(MemoryLayout<integer_t>.size)
        )

        return (totalUsage / Double(numCPUs)) * 100.0
    }

    private func readMemoryUsage() -> Double {
        var vmStats = vm_statistics64_data_t()
        var infoCount = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &infoCount)
            }
        }
        guard result == KERN_SUCCESS else { return memoryUsage }

        let pageSize = UInt64(vm_page_size)
        let used = (UInt64(vmStats.active_count) + UInt64(vmStats.wire_count)) * pageSize

        var totalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)

        return totalMemory > 0 ? Double(used) / Double(totalMemory) * 100.0 : memoryUsage
    }

    private func updateNetworkSpeed() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        defer { freeifaddrs(ifaddr) }

        var totalSent: UInt64 = 0
        var totalReceived: UInt64 = 0

        var ptr = ifaddr
        while let iface = ptr {
            defer { ptr = iface.pointee.ifa_next }
            let flags = Int32(iface.pointee.ifa_flags)
            guard flags & IFF_LOOPBACK == 0,
                  flags & IFF_UP != 0,
                  iface.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                  let data = iface.pointee.ifa_data?.assumingMemoryBound(to: if_data.self)
            else { continue }

            totalSent += UInt64(data.pointee.ifi_obytes)
            totalReceived += UInt64(data.pointee.ifi_ibytes)
        }

        let now = Date()
        if let prev = previousNetworkStats {
            let elapsed = now.timeIntervalSince(prev.timestamp)
            if elapsed > 0 {
                let sentDelta = totalSent >= prev.bytesSent ? totalSent - prev.bytesSent : totalSent
                let recvDelta = totalReceived >= prev.bytesReceived ? totalReceived - prev.bytesReceived : totalReceived
                uploadSpeed = Double(sentDelta) / elapsed
                downloadSpeed = Double(recvDelta) / elapsed
            }
        }

        previousNetworkStats = NetworkStats(bytesSent: totalSent, bytesReceived: totalReceived, timestamp: now)
    }

    private func updateDiskUsage() {
        let url = URL(fileURLWithPath: "/")
        guard let vals = try? url.resourceValues(forKeys: [
                  .volumeTotalCapacityKey,
                  .volumeAvailableCapacityKey]),
              let total = vals.volumeTotalCapacity, total > 0,
              let avail = vals.volumeAvailableCapacity else { return }
        let used = max(0, total - avail)
        diskUsage = Double(used) / Double(total) * 100
        diskUsedText = formatGB(Int64(used))
        diskTotalText = formatGB(Int64(total))
    }

    private func formatGB(_ bytes: Int64) -> String {
        String(format: "%.0fG", Double(bytes) / 1_073_741_824)
    }

    func formattedSpeed(_ bytesPerSec: Double) -> String {
        let value = max(0, bytesPerSec)
        if value >= 1_048_576 {
            return String(format: "%.1fM", value / 1_048_576)
        } else if value >= 1024 {
            return String(format: "%.0fK", value / 1024)
        } else {
            return String(format: "%.0fB", value)
        }
    }
}
