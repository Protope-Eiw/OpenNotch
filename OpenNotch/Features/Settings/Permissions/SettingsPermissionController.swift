import Combine
import CoreBluetooth
import EventKit
import Foundation
internal import AppKit
import SwiftUI

#if canImport(ApplicationServices)
import ApplicationServices
#endif

enum Kind: String {
    case accessibility
    case bluetooth
    case mediaControls
    case screenRecording
    case calendar
}

struct PermissionItem: Identifiable {
    let kind: Kind
    let titleKey: String
    let fallbackTitle: String
    let descriptionKey: String
    let fallbackDescription: String
    let assetImageName: String?
    let systemImage: String
    let tintColor: Color
    let isGranted: Bool
    let actionTitleKey: String?
    let fallbackActionTitle: String?
    let accessibilityIdentifier: String

    var id: String { kind.rawValue }
}

@MainActor
final class SettingsPermissionController: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published private(set) var isAccessibilityTrusted: Bool
    @Published private(set) var bluetoothAuthorization: CBManagerAuthorization
    @Published private(set) var canPostMediaKeyEvents: Bool
    @Published private(set) var canCaptureScreenAudio: Bool
    @Published private(set) var calendarAuthStatus: EKAuthorizationStatus

    private let ekStore = EKEventStore.app
    private var cancellables = Set<AnyCancellable>()

    private var aggressiveRefreshTask: Task<Void, Never>?

    private let bluetoothManager: CBCentralManager

    private static let privacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )
    private static let bluetoothPrivacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
    )
    private static let screenCapturePrivacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )
    private static let calendarPrivacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
    )

    init(notificationCenter: NotificationCenter = .default) {
        self.bluetoothAuthorization = Self.currentBluetoothAuthorizationStatus()
        self.isAccessibilityTrusted = Self.currentAccessibilityTrustState()
        self.canPostMediaKeyEvents = Self.currentPostEventAccessState()
        self.canCaptureScreenAudio = Self.currentScreenCaptureAccessState()
        self.calendarAuthStatus = EKEventStore.authorizationStatus(for: .event)

        self.bluetoothManager = CBCentralManager(
            delegate: nil,
            queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )

        super.init()

        self.bluetoothManager.delegate = self

        notificationCenter.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    self?.refresh()
                }
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refresh),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(refresh),
            name: NSNotification.Name("com.apple.accessibility.api"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(refresh),
            name: NSNotification.Name("com.apple.bluetooth.status"),
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    private func startAggressiveRefresh() {
        aggressiveRefreshTask?.cancel()
        aggressiveRefreshTask = Task { @MainActor in
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                refresh()
            }
        }
    }

    @objc func refresh() {
        bluetoothAuthorization = Self.currentBluetoothAuthorizationStatus()
        isAccessibilityTrusted = Self.currentAccessibilityTrustState()
        canPostMediaKeyEvents = Self.currentPostEventAccessState()
        canCaptureScreenAudio = Self.currentScreenCaptureAccessState()
        calendarAuthStatus = resolveCalendarAuthStatus()
    }

    private func resolveCalendarAuthStatus() -> EKAuthorizationStatus {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess || status == .writeOnly {
            return status
        }
        if !ekStore.calendars(for: .event).isEmpty {
            return .fullAccess
        }
        return status
    }

    var permissionItems: [PermissionItem] {
        [
            PermissionItem(
                kind: .accessibility,
                titleKey: "settings.permissions.accessibility.title",
                fallbackTitle: "Accessibility",
                descriptionKey: "settings.permissions.accessibility.description",
                fallbackDescription: "Allow Accessibility access to use custom volume and brightness HUD controls.",
                assetImageName: nil,
                systemImage: "hand.raised.fill",
                tintColor: .orange,
                isGranted: isAccessibilityTrusted,
                actionTitleKey: isAccessibilityTrusted ? nil : "settings.permissions.action.grantAccess",
                fallbackActionTitle: isAccessibilityTrusted ? nil : "Grant Access",
                accessibilityIdentifier: "settings.permissions.accessibility"
            ),
            PermissionItem(
                kind: .bluetooth,
                titleKey: "settings.permissions.bluetooth.title",
                fallbackTitle: "Bluetooth",
                descriptionKey: "settings.permissions.bluetooth.description",
                fallbackDescription: "Allow Bluetooth access to read battery levels from supported accessories.",
                assetImageName: "bluetooth.white",
                systemImage: "dot.radiowaves.left.and.right",
                tintColor: .blue,
                isGranted: bluetoothAuthorization == .allowedAlways,
                actionTitleKey: bluetoothActionTitleKey,
                fallbackActionTitle: bluetoothFallbackActionTitle,
                accessibilityIdentifier: "settings.permissions.bluetooth"
            ),
            PermissionItem(
                kind: .mediaControls,
                titleKey: "settings.permissions.mediaControls.title",
                fallbackTitle: "Media Controls",
                descriptionKey: "settings.permissions.mediaControls.description",
                fallbackDescription: "Allow media control event access so play, pause, and track buttons work from Now Playing.",
                assetImageName: nil,
                systemImage: "music.note",
                tintColor: .pink,
                isGranted: canPostMediaKeyEvents,
                actionTitleKey: canPostMediaKeyEvents ? nil : "settings.permissions.action.grantAccess",
                fallbackActionTitle: canPostMediaKeyEvents ? nil : "Grant Access",
                accessibilityIdentifier: "settings.permissions.mediaControls"
            ),
            PermissionItem(
                kind: .screenRecording,
                titleKey: "settings.permissions.screenRecording.title",
                fallbackTitle: "Screen Recording",
                descriptionKey: "settings.permissions.screenRecording.description",
                fallbackDescription: "Allow Screen Recording access so the audio-reactive Now Playing equalizer can listen to system audio.",
                assetImageName: nil,
                systemImage: "record.circle",
                tintColor: .red,
                isGranted: canCaptureScreenAudio,
                actionTitleKey: canCaptureScreenAudio ? nil : "settings.permissions.action.grantAccess",
                fallbackActionTitle: canCaptureScreenAudio ? nil : "Grant Access",
                accessibilityIdentifier: "settings.permissions.screenRecording"
            ),
            PermissionItem(
                kind: .calendar,
                titleKey: "settings.permissions.calendar.title",
                fallbackTitle: "Calendar",
                descriptionKey: "settings.permissions.calendar.description",
                fallbackDescription: "Allow Calendar access to show your events in the dashboard.",
                assetImageName: nil,
                systemImage: "calendar",
                tintColor: .red,
                isGranted: calendarAuthStatus == .fullAccess || calendarAuthStatus == .writeOnly,
                actionTitleKey: calendarAuthStatus == .fullAccess || calendarAuthStatus == .writeOnly ? nil : (
                    calendarAuthStatus == .notDetermined ?
                    "settings.permissions.action.grantAccess" :
                    "settings.permissions.action.openPrivacySettings"
                ),
                fallbackActionTitle: calendarAuthStatus == .fullAccess || calendarAuthStatus == .writeOnly ? nil : (
                    calendarAuthStatus == .notDetermined ? "Grant Access" : "Open Privacy Settings"
                ),
                accessibilityIdentifier: "settings.permissions.calendar"
            )
        ]
    }

    func performAction(for kind: Kind) {
        switch kind {
        case .accessibility:
            requestAccessibilityAccess()
        case .bluetooth:
            requestBluetoothAccess()
        case .mediaControls:
            requestPostEventAccess()
        case .screenRecording:
            requestScreenCaptureAccess()
        case .calendar:
            requestCalendarAccess()
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        refresh()
    }

    private func requestAccessibilityAccess() {
        guard !Self.currentAccessibilityTrustState() else { refresh(); return }
        #if canImport(ApplicationServices)
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        #endif
        scheduleDelayedRefresh()
    }

    private func requestPostEventAccess() {
        guard !Self.currentPostEventAccessState() else { refresh(); return }
        #if canImport(ApplicationServices)
        _ = CGRequestPostEventAccess()
        #endif
        scheduleDelayedRefresh()
    }

    private func requestScreenCaptureAccess() {
        guard !Self.currentScreenCaptureAccessState() else { refresh(); return }
        #if canImport(ApplicationServices)
        _ = CGRequestScreenCaptureAccess()
        #endif
        scheduleDelayedRefresh()
    }

    private func scheduleDelayedRefresh() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            refresh()
        }
        startAggressiveRefresh()
    }

    private var bluetoothActionTitleKey: String? {
        switch bluetoothAuthorization {
        case .allowedAlways:
            return nil
        case .notDetermined:
            return "settings.permissions.action.grantAccess"
        case .restricted, .denied:
            return "settings.permissions.action.openPrivacySettings"
        @unknown default:
            return "settings.permissions.action.openPrivacySettings"
        }
    }

    private var bluetoothFallbackActionTitle: String? {
        switch bluetoothAuthorization {
            case .allowedAlways:
                return nil
            case .notDetermined:
                return "Grant Access"
            case .restricted, .denied:
                return "Open Privacy Settings"
            @unknown default:
                return "Open Privacy Settings"
        }
    }

    private func requestBluetoothAccess() {
        switch Self.currentBluetoothAuthorizationStatus() {
        case .allowedAlways:
            refresh()
        case .notDetermined:
            bluetoothManager.scanForPeripherals(withServices: nil, options: nil)
            bluetoothManager.stopScan()
        case .restricted, .denied:
            Self.openBluetoothPrivacySettings()
        @unknown default:
            Self.openBluetoothPrivacySettings()
        }
    }

    private static func openPrivacySettings() {
        guard let privacySettingsURL else { return }
        NSWorkspace.shared.open(privacySettingsURL)
    }

    private static func openBluetoothPrivacySettings() {
        guard let bluetoothPrivacySettingsURL else { return }
        NSWorkspace.shared.open(bluetoothPrivacySettingsURL)
    }

    private static func openScreenCapturePrivacySettings() {
        guard let screenCapturePrivacySettingsURL else { return }
        NSWorkspace.shared.open(screenCapturePrivacySettingsURL)
    }

    private func requestCalendarAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status != .fullAccess else { refresh(); return }
        if status == .writeOnly {
            refresh()
            startAggressiveRefresh()
            return
        }
        guard status == .notDetermined else {
            Self.openCalendarPrivacySettings()
            refresh()
            startAggressiveRefresh()
            return
        }
        Task { @MainActor in
            do {
                _ = try await ekStore.requestFullAccessToEvents()
            } catch {
                Self.openCalendarPrivacySettings()
            }
            calendarAuthStatus = EKEventStore.authorizationStatus(for: .event)
            startAggressiveRefresh()
        }
    }

    private static func openCalendarPrivacySettings() {
        guard let calendarPrivacySettingsURL else { return }
        NSWorkspace.shared.open(calendarPrivacySettingsURL)
    }

    private static func currentAccessibilityTrustState() -> Bool {
        #if canImport(ApplicationServices)
        AXIsProcessTrusted()
        #else
        true
        #endif
    }

    private static func currentPostEventAccessState() -> Bool {
        #if canImport(ApplicationServices)
        CGPreflightPostEventAccess()
        #else
        true
        #endif
    }

    private static func currentScreenCaptureAccessState() -> Bool {
        #if canImport(ApplicationServices)
        CGPreflightScreenCaptureAccess()
        #else
        true
        #endif
    }

    private static func currentBluetoothAuthorizationStatus() -> CBManagerAuthorization {
        CBManager.authorization
    }
}
