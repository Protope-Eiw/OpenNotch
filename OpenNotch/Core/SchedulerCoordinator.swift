import Foundation

enum MonitorName: CaseIterable {
    case systemMonitor
    case nowPlaying
    case downloads
    case timer
    case screenRecording
    case hardwareHUD
    case bluetooth
    case lockScreen
}

@MainActor
final class SchedulerCoordinator {
    private var activeMonitors: Set<MonitorName> = []

    private let systemMonitorViewModel: SystemMonitorViewModel
    private let nowPlayingViewModel: NowPlayingViewModel
    private let downloadViewModel: DownloadViewModel
    private let timerViewModel: TimerViewModel
    private let screenRecordingViewModel: ScreenRecordingViewModel
    private let hardwareHUDMonitor: HardwareHUDMonitor
    private let lockScreenManager: LockScreenManager

    init(
        systemMonitorViewModel: SystemMonitorViewModel,
        nowPlayingViewModel: NowPlayingViewModel,
        downloadViewModel: DownloadViewModel,
        timerViewModel: TimerViewModel,
        screenRecordingViewModel: ScreenRecordingViewModel,
        hardwareHUDMonitor: HardwareHUDMonitor,
        lockScreenManager: LockScreenManager
    ) {
        self.systemMonitorViewModel = systemMonitorViewModel
        self.nowPlayingViewModel = nowPlayingViewModel
        self.downloadViewModel = downloadViewModel
        self.timerViewModel = timerViewModel
        self.screenRecordingViewModel = screenRecordingViewModel
        self.hardwareHUDMonitor = hardwareHUDMonitor
        self.lockScreenManager = lockScreenManager
    }

    func start(_ monitor: MonitorName) {
        guard !activeMonitors.contains(monitor) else { return }
        activeMonitors.insert(monitor)

        switch monitor {
        case .systemMonitor:
            systemMonitorViewModel.startMonitoring()
        case .nowPlaying:
            nowPlayingViewModel.startMonitoring()
        case .downloads:
            downloadViewModel.startMonitoring()
        case .timer:
            timerViewModel.startMonitoring()
        case .screenRecording:
            screenRecordingViewModel.startMonitoring()
        case .hardwareHUD:
            hardwareHUDMonitor.startMonitoring()
        case .bluetooth:
            break
        case .lockScreen:
            lockScreenManager.startMonitoring()
        }
    }

    func stop(_ monitor: MonitorName) {
        guard activeMonitors.contains(monitor) else { return }
        activeMonitors.remove(monitor)

        switch monitor {
        case .systemMonitor:
            systemMonitorViewModel.stopMonitoring()
        case .nowPlaying:
            nowPlayingViewModel.stopMonitoring()
        case .downloads:
            downloadViewModel.stopMonitoring()
        case .timer:
            timerViewModel.stopMonitoring()
        case .screenRecording:
            screenRecordingViewModel.stopMonitoring()
        case .hardwareHUD:
            hardwareHUDMonitor.stopMonitoring()
        case .bluetooth:
            break
        case .lockScreen:
            lockScreenManager.stopMonitoring()
        }
    }

    func startAll() {
        for monitor in MonitorName.allCases {
            start(monitor)
        }
    }

    func stopAll() {
        for monitor in activeMonitors {
            stop(monitor)
        }
    }

    func isActive(_ monitor: MonitorName) -> Bool {
        activeMonitors.contains(monitor)
    }
}
