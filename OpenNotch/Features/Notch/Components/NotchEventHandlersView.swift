import Combine
import SwiftUI

struct NotchEventHandlersView: View {
    let notchEventCoordinator: NotchEventCoordinator
    let powerViewModel: PowerViewModel
    let bluetoothViewModel: BluetoothViewModel
    let networkViewModel: NetworkViewModel
    let downloadViewModel: DownloadViewModel
    let focusViewModel: FocusViewModel
    let airDropViewModel: AirDropNotchViewModel
    let settingsViewModel: SettingsViewModel
    let nowPlayingViewModel: NowPlayingViewModel
    let timerViewModel: TimerViewModel
    let screenRecordingViewModel: ScreenRecordingViewModel
    let lockScreenManager: LockScreenManager

     var body: some View {
         Color.clear
             .onReceive(powerViewModel.event) { event in
                 Task { @MainActor in
                     notchEventCoordinator.handlePowerEvent(event)
                 }
             }
             .onReceive(bluetoothViewModel.$event.compactMap { $0 }) { event in
                 Task { @MainActor in
                     notchEventCoordinator.handleBluetoothEvent(event)
                 }
             }
              .onReceive(networkViewModel.$networkEvent.compactMap { $0 }) { event in
                 Task { @MainActor in
                     notchEventCoordinator.handleNetworkEvent(event)
                 }
             }
              .onReceive(downloadViewModel.$event.compactMap { $0 }) { event in
                 Task { @MainActor in
                     notchEventCoordinator.handleDownloadEvent(event)
                 }
             }
              .onReceive(focusViewModel.$focusEvent.compactMap { $0 }) { event in
                 Task { @MainActor in
                     notchEventCoordinator.handleFocusEvent(event)
                 }
             }
              .onReceive(airDropViewModel.$event.compactMap { $0 }) { event in
                 Task { @MainActor in
                     notchEventCoordinator.handleAirDropEvent(event)
                 }
             }
             .onReceive(settingsViewModel.notchSizeEvent) { event in
                 Task { @MainActor in
                     notchEventCoordinator.handleNotchWidthEvent(event)
                 }
             }
             .onReceive(nowPlayingViewModel.$event.compactMap { $0 }) { event in
                 Task { @MainActor in
                     notchEventCoordinator.handleNowPlayingEvent(event)
                 }
             }
             .onReceive(timerViewModel.$event.compactMap { $0 }) { event in
                 Task { @MainActor in
                     notchEventCoordinator.handleTimerEvent(event)
                 }
             }
             .onReceive(screenRecordingViewModel.$event.compactMap { $0 }) { event in
                 Task { @MainActor in
                     notchEventCoordinator.handleScreenRecordingEvent(event)
                 }
             }
             .onReceive(lockScreenManager.$event.compactMap { $0 }) { event in
                 Task { @MainActor in
                     notchEventCoordinator.handleLockScreenEvent(event)
                 }
             }
     }
}
