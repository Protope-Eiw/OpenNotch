import Foundation
import Network
import SystemConfiguration

final class NetworkMonitor: NetworkMonitoring {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    private let wifiStoreKey = "State:/Network/Interface/en0/AirPort" as CFString
    private let wifiStore: SCDynamicStore

    var onStatusChange: ((_ wifi: Bool, _ hotspot: Bool, _ vpn: Bool) -> Void)?
    private(set) var currentWiFiName: String?
    private(set) var currentVPNName: String?
    private(set) var isInternetAvailable = true

    deinit {
        stopMonitoring()
    }

    init() {
        let storeName = "OpenNotch.NetworkMonitor" as CFString
        var dynamicStore: SCDynamicStore?
        let pattern = ["State:/Network/Interface/en0/AirPort"] as CFArray

        SCDynamicStoreCreate(nil, storeName, nil, nil).flatMap { store in
            SCDynamicStoreSetNotificationKeys(store, nil, pattern)
            dynamicStore = store
        }

        self.wifiStore = dynamicStore ?? SCDynamicStoreCreate(nil, storeName, nil, nil)!
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.updateStatus(path: path)
        }
        monitor.start(queue: queue)
    }

    private func updateStatus(path: NWPath) {
        let hasInternetConnection = path.status == .satisfied
        let isWifi = hasInternetConnection && path.usesInterfaceType(.wifi)
        
        let isHotspot = isWifi && path.isExpensive
        
        let isVpn = hasInternetConnection && path.availableInterfaces.contains { interface in
            let name = interface.name.lowercased()
            return name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")
        }

        let wifiName = resolveWiFiName(isConnected: isWifi && !isHotspot)
        let vpnName = resolveVPNName(isConnected: isVpn)

        DispatchQueue.main.async {
            self.currentWiFiName = wifiName
            self.currentVPNName = vpnName
            self.isInternetAvailable = hasInternetConnection
            self.onStatusChange?(isWifi && !isHotspot, isHotspot, isVpn)
        }
    }

    func stopMonitoring() {
        monitor.pathUpdateHandler = nil
        monitor.cancel()
    }

    private func resolveWiFiName(isConnected: Bool) -> String? {
        guard isConnected else { return nil }

        if let info = SCDynamicStoreCopyValue(wifiStore, wifiStoreKey) as? [String: Any],
           let ssidData = info["SSID"] as? Data,
           let ssid = String(data: ssidData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !ssid.isEmpty {
            return ssid
        }

        if let info = SCDynamicStoreCopyValue(wifiStore, wifiStoreKey) as? [String: Any],
           let ssidStr = info["SSID_STR"] as? String {
            let cleaned = ssidStr.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }

        return nil
    }

    private func resolveVPNName(isConnected: Bool) -> String? {
        guard isConnected else { return nil }
        guard let store = SCDynamicStoreCreate(nil, "OpenNotch.NetworkMonitor" as CFString, nil, nil),
              let preferences = SCPreferencesCreate(nil, "OpenNotch.NetworkMonitor" as CFString, nil),
              let services = SCNetworkServiceCopyAll(preferences) as? [SCNetworkService] else {
            return nil
        }

        let activeServiceIDs = activeVPNServiceIDs(from: store)
        let activeServices = services.filter { service in
            guard let serviceID = SCNetworkServiceGetServiceID(service) as String? else {
                return false
            }

            return activeServiceIDs.contains(serviceID)
        }

        if let displayName = activeServices
            .compactMap(serviceDisplayName(for:))
            .first(where: { !$0.isEmpty }) {
            return displayName
        }

        if let displayName = services
            .filter(isLikelyVPNService(_:))
            .compactMap(serviceDisplayName(for:))
            .first(where: { !$0.isEmpty }) {
            return displayName
        }

        return nil
    }

    private func activeVPNServiceIDs(from store: SCDynamicStore) -> Set<String> {
        let patterns = [
            "State:/Network/Service/.*/PPP",
            "State:/Network/Service/.*/IPSec",
            "State:/Network/Service/.*/VPN"
        ]

        return patterns.reduce(into: Set<String>()) { result, pattern in
            guard let keys = SCDynamicStoreCopyKeyList(store, pattern as CFString) as? [String] else {
                return
            }

            for key in keys {
                guard let serviceID = extractServiceID(from: key) else {
                    continue
                }

                result.insert(serviceID)
            }
        }
    }

    private func extractServiceID(from key: String) -> String? {
        let components = key.split(separator: "/")
        guard let serviceIndex = components.firstIndex(of: "Service"),
              components.indices.contains(serviceIndex + 1) else {
            return nil
        }

        return String(components[serviceIndex + 1])
    }

    private func serviceDisplayName(for service: SCNetworkService) -> String? {
        let name = (SCNetworkServiceGetName(service) as String?)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return name?.isEmpty == false ? name : nil
    }

    private func isLikelyVPNService(_ service: SCNetworkService) -> Bool {
        guard let interface = SCNetworkServiceGetInterface(service) else {
            return false
        }

        let values = [
            SCNetworkInterfaceGetInterfaceType(interface) as String?,
            SCNetworkInterfaceGetLocalizedDisplayName(interface) as String?
        ]
        .compactMap { $0?.lowercased() }

        return values.contains { value in
            value.contains("vpn") ||
            value.contains("ppp") ||
            value.contains("ipsec") ||
            value.contains("l2tp") ||
            value.contains("utun")
        }
    }
}
