import Foundation
import CoreLocation
import CoreWLAN
import Network
import SystemConfiguration

final class NetworkMonitor: NSObject, NetworkMonitoring, CLLocationManagerDelegate {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    private let wifiStoreKey = "State:/Network/Interface/en0/AirPort" as CFString
    private let wifiStore: SCDynamicStore
    private var locationManager: CLLocationManager?

    var onStatusChange: ((_ wifi: Bool, _ hotspot: Bool, _ vpn: Bool) -> Void)?
    private(set) var currentWiFiName: String?
    private(set) var currentVPNName: String?
    private(set) var isInternetAvailable = true

    deinit {
        stopMonitoring()
    }

    override init() {
        let storeName = "OpenNotch.NetworkMonitor" as CFString
        var dynamicStore: SCDynamicStore?
        let pattern = ["State:/Network/Interface/en0/AirPort"] as CFArray

        SCDynamicStoreCreate(nil, storeName, nil, nil).flatMap { store in
            SCDynamicStoreSetNotificationKeys(store, nil, pattern)
            dynamicStore = store
        }

        self.wifiStore = dynamicStore ?? SCDynamicStoreCreate(nil, storeName, nil, nil)!
        super.init()
        if !Self.isRunningTests {
            DispatchQueue.main.async { [weak self] in
                self?.configureLocationManager()
            }
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            NSClassFromString("XCTestCase") != nil
    }

    private func configureLocationManager() {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        self.locationManager = locationManager
        requestLocationAuthorizationIfNeeded(locationManager)
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.updateStatus(path: path)
        }
        monitor.start(queue: queue)
    }

    func refreshStatus() {
        updateStatus(path: monitor.currentPath)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refreshStatus()
    }

    private func requestLocationAuthorizationIfNeeded(_ locationManager: CLLocationManager) {
        guard CLLocationManager.locationServicesEnabled() else { return }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse, .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    private func updateStatus(path: NWPath) {
        let hasInternetConnection = path.status == .satisfied
        let pathUsesWiFi = hasInternetConnection && path.usesInterfaceType(.wifi)
        let isHotspot = pathUsesWiFi && path.isExpensive
        let wifiName = resolveWiFiName(isConnected: hasInternetConnection && !isHotspot)
        let isWifi = pathUsesWiFi || wifiName != nil
        
        let isVpn = hasInternetConnection && path.availableInterfaces.contains { interface in
            let name = interface.name.lowercased()
            return name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")
        }

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

        if let ssid = ssidFromDynamicStore() {
            return ssid
        }

        if let ssid = ssidFromCoreWLAN() {
            return ssid
        }

        return nil
    }

    private func ssidFromDynamicStore() -> String? {
        guard let info = SCDynamicStoreCopyValue(wifiStore, wifiStoreKey) as? [String: Any] else {
            return nil
        }

        if let ssidData = info["SSID"] as? Data,
           let ssid = cleanedSSID(String(data: ssidData, encoding: .utf8)) {
            return ssid
        }

        if let ssid = cleanedSSID(info["SSID_STR"] as? String) {
            return ssid
        }

        return nil
    }

    private func ssidFromCoreWLAN() -> String? {
        let client = CWWiFiClient.shared()
        let interfaceNames = [client.interface()?.interfaceName] + (client.interfaces()?.map(\.interfaceName) ?? [])

        for interfaceName in interfaceNames.compactMap({ $0 }) {
            guard let ssid = cleanedSSID(client.interface(withName: interfaceName)?.ssid()) else {
                continue
            }

            return ssid
        }

        return nil
    }

    private func cleanedSSID(_ value: String?) -> String? {
        guard let value else { return nil }

        let cleaned = value
            .unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) }
            .map(String.init)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned != "<redacted>" else { return nil }
        return cleaned.isEmpty ? nil : cleaned
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
