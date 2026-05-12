//
//  AppDelegate.swift
//  OpenNotch
//
//  Created by Евгений Петрукович on 2/28/26.
//

import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let isRunningUITests: Bool
    let container: AppContainer

    var powerService: PowerService { container.powerService }
    var bluetoothViewModel: BluetoothViewModel { container.bluetoothViewModel }
    var powerViewModel: PowerViewModel { container.powerViewModel }
    var networkViewModel: NetworkViewModel { container.networkViewModel }
    var downloadViewModel: DownloadViewModel { container.downloadViewModel }
    var focusViewModel: FocusViewModel { container.focusViewModel }
    var settingsViewModel: SettingsViewModel { container.settingsViewModel }
    var nowPlayingViewModel: NowPlayingViewModel { container.nowPlayingViewModel }
    var timerViewModel: TimerViewModel { container.timerViewModel }
    var screenRecordingViewModel: ScreenRecordingViewModel { container.screenRecordingViewModel }
    var airDropViewModel: AirDropNotchViewModel { container.airDropViewModel }
    var lockScreenManager: LockScreenManager { container.lockScreenManager }
    var hardwareHUDMonitor: HardwareHUDMonitor { container.hardwareHUDMonitor }
    var notchViewModel: NotchViewModel { container.notchViewModel }
    var airDropController: NotchAirDropController { container.airDropController }
    var notchEventCoordinator: NotchEventCoordinator { container.notchEventCoordinator }
    var lockScreenPanelManager: LockScreenPanelManager { container.lockScreenPanelManager }
    var lockScreenLiveActivityWindowManager: LockScreenLiveActivityWindowManager {
        container.lockScreenLiveActivityWindowManager
    }
    
    var window: OverlayPanelWindow!
    var notchWindows: [CGDirectDisplayID: OverlayPanelWindow] = [:]
    var notchViewModels: [CGDirectDisplayID: NotchViewModel] = [:]
    var localClickMonitor: Any?
    let globalClickMonitor = GlobalClickMonitor()
    var cancellables = Set<AnyCancellable>()
    var isPrimaryWindowSuspendedForLock = false
    var mousePollingTimer: Timer?
    var lastMouseScreenID: CGDirectDisplayID?
    
    override init() {
        let isRunningUITests = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        self.isRunningUITests = isRunningUITests
        self.container = AppContainer(isRunningUITests: isRunningUITests)
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != .current }
            .forEach { $0.terminate() }

        applyActivationPolicy(
            showsDockIcon: isRunningUITests || settingsViewModel.application.isDockIconVisible
        )
        observeAppearanceModeChanges()
        observeDisplayLocationChanges()
        observeFullscreenVisibilityChanges()
        observeDockIconVisibilityChanges()
        observeHUDConfigurationChanges()
        observeFeatureMonitoringChanges()
        observeLockScreenWindowHandoff()

        if !isRunningUITests {
            createNotchWindow()
            startMousePolling()
            observeOutsideClickDismissal()
            _ = lockScreenPanelManager
            _ = lockScreenLiveActivityWindowManager
            hardwareHUDMonitor.startMonitoring()

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(updateWindowFrame),
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
            observeWorkspaceChanges()

            DispatchQueue.main.async {
                let ownWindows = [self.window].compactMap { $0 } + Array(self.notchWindows.values)
                let keepWindows = Set(ownWindows.map(ObjectIdentifier.init))
                for w in NSApp.windows {
                    guard let panel = w as? OverlayPanelWindow else { continue }
                    if !keepWindows.contains(ObjectIdentifier(panel)) {
                        panel.orderOut(nil)
                    }
                }
            }
        }

        if !isRunningUITests {
            notchEventCoordinator.checkFirstLaunch()
            container.systemMonitorViewModel.startMonitoring()
        }

        lockScreenManager.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        lockScreenManager.stopMonitoring()
        nowPlayingViewModel.stopMonitoring()
        downloadViewModel.stopMonitoring()
        timerViewModel.stopMonitoring()
        screenRecordingViewModel.stopMonitoring()
        hardwareHUDMonitor.stopMonitoring()
        container.systemMonitorViewModel.stopMonitoring()
        if !isRunningUITests {
            lockScreenPanelManager.invalidate()
            lockScreenLiveActivityWindowManager.invalidate()
        }
        stopOutsideClickMonitoring()
        stopMousePolling()
        destroyNotchWindows()
    }

    func applyActivationPolicy(showsDockIcon: Bool) {
        let targetPolicy: NSApplication.ActivationPolicy = showsDockIcon ? .regular : .accessory

        guard NSApp.activationPolicy() != targetPolicy else { return }

        NSApp.setActivationPolicy(targetPolicy)

        if showsDockIcon {
            NSApp.activate(ignoringOtherApps: false)
        }
    }
}
