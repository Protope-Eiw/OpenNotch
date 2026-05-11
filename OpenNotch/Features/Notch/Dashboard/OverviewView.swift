import SwiftUI
import Combine

struct OverviewView: View {
    @ObservedObject var systemMonitorViewModel: SystemMonitorViewModel
    @ObservedObject var pomodoroViewModel: PomodoroViewModel

    @AppStorage(AppStorageKeys.Overview.showApps)         private var showApps       = true
    @AppStorage(AppStorageKeys.Overview.showTimeDate)     private var showTimeDate   = true
    @AppStorage(AppStorageKeys.Overview.showSystemInfo)   private var showSystemInfo = true
    @AppStorage(AppStorageKeys.Overview.showPomodoro)     private var showPomodoro   = true
    @AppStorage(AppStorageKeys.Overview.hideAppNames)     private var hideAppNames   = false
    @AppStorage(AppStorageKeys.Overview.showWeather)      private var showWeather    = true
    @AppStorage(AppStorageKeys.Overview.pomodoroDuration) private var workMinutes    = 25

    @StateObject private var pinnedAppsStore = PinnedAppsStore()
    @StateObject private var weatherService  = WeatherService()
    @State private var now = Date()
    @State private var showAppPicker = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            if showApps {
                appsColumn
                if showTimeDate || showSystemInfo || showPomodoro { columnDivider }
            }
            if showTimeDate {
                timeDateColumn
                if showSystemInfo || showPomodoro { columnDivider }
            }
            if showSystemInfo {
                systemInfoColumn
                if showPomodoro { columnDivider }
            }
            if showPomodoro {
                pomodoroColumn
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(clock) { now = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .pinnedAppsDidChange)) { _ in
            pinnedAppsStore.load()
        }
        .onAppear {
            if showWeather { weatherService.requestAndFetch() }
        }
        .onChange(of: showWeather) { _, on in
            if on { weatherService.requestAndFetch() }
        }
    }

    private var columnDivider: some View {
        Color.white.opacity(0.06).frame(width: 0.5)
    }

    private var appsColumn: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if pinnedAppsStore.apps.isEmpty {
                    VStack(spacing: 5) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.12))
                        Text(L10n.app("appLauncher.tapToAdd", fallback: "Tap + to add apps"))
                            .font(.system(size: 8))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.2))
                    }
                } else {
                    let apps = pinnedAppsStore.apps
                    let cols = apps.count <= 4 ? 2 : apps.count <= 9 ? 3 : 4
                    let iconW: CGFloat = hideAppNames ? 30 : 26
                    let cellW: CGFloat = hideAppNames ? 32 : 32
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(cellW), spacing: 4), count: cols),
                        alignment: .center,
                        spacing: 4
                    ) {
                        ForEach(apps, id: \.self) { url in
                            Button { NSWorkspace.shared.open(url) } label: {
                                VStack(spacing: 2) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                        .resizable().aspectRatio(contentMode: .fit)
                                        .frame(width: iconW, height: iconW)
                                    if !hideAppNames {
                                        Text(url.deletingPathExtension().lastPathComponent)
                                            .font(.system(size: 7))
                                            .lineLimit(1)
                                            .foregroundStyle(.white.opacity(0.5))
                                            .frame(width: cellW)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    pinnedAppsStore.remove(url)
                                } label: {
                                    Label(L10n.app("appLauncher.remove", fallback: "Remove from Quick Launch"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                showAppPicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(5)
            .popover(isPresented: $showAppPicker, arrowEdge: .bottom) {
                OverviewAppPickerView(store: pinnedAppsStore)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var timeDateColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(now, format: .dateTime.weekday(.abbreviated).month().day())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.green.opacity(0.85))

            Text(now, format: .dateTime.hour().minute())
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if showWeather {
                if let temp = weatherService.temperature {
                    HStack(spacing: 3) {
                        Image(systemName: weatherService.symbolName)
                            .font(.system(size: 10))
                        Text(weatherService.conditionText.isEmpty
                             ? String(format: "%.0f\u{00B0}", temp)
                             : String(format: "%@ %.0f\u{00B0}", weatherService.conditionText, temp))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Color.orange.opacity(0.8))
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "location.slash").font(.system(size: 9))
                        Text(L10n.app("weather.fetching", fallback: "Fetching weather\u{2026}")).font(.system(size: 9))
                    }
                    .foregroundStyle(.white.opacity(0.2))
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var systemInfoColumn: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                statBlock("\(Int(systemMonitorViewModel.cpuUsage))%",  "CPU",
                          Color.thresholdColor(systemMonitorViewModel.cpuUsage,  warn: 50, danger: 80))
                statBlock("\(Int(systemMonitorViewModel.memoryUsage))%", "MEM",
                          Color.thresholdColor(systemMonitorViewModel.memoryUsage, warn: 70, danger: 85))
                statBlock("\(Int(systemMonitorViewModel.diskUsage))%",  "DISK",
                          Color.thresholdColor(systemMonitorViewModel.diskUsage,  warn: 80, danger: 90))
            }
            HStack(spacing: 3) {
                Image(systemName: "internaldrive").font(.system(size: 9))
                Text("\(systemMonitorViewModel.diskUsedText) / \(systemMonitorViewModel.diskTotalText)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statBlock(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var pomodoroColumn: some View {
        let isIdle      = pomodoroViewModel.state == .idle
        let accentColor: Color = pomodoroViewModel.phase == .work ? .orange : .mint
        let total       = max(1, pomodoroViewModel.phaseTotalSeconds)
        let progress    = isIdle ? 1.0 : min(1.0, Double(pomodoroViewModel.timeRemaining) / Double(total))

        return ZStack {
            Circle()
                .fill(Color(red: 0.14, green: 0.10, blue: 0.08))

            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 3)
                .padding(2)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(accentColor.opacity(isIdle ? 0.4 : 0.9),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .padding(2)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: pomodoroViewModel.timeRemaining)

            VStack(spacing: 6) {
                Text(pomodoroViewModel.timeString)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Text(isIdle ? "\(workMinutes)\(L10n.app("pomodoro.minutes.suffix", fallback: "m"))"
                     : pomodoroViewModel.phase == .work ? L10n.app("pomodoro.focusing", fallback: "Focusing") : L10n.app("pomodoro.resting", fallback: "Resting"))
                    .font(.system(size: 9))
                    .foregroundStyle(isIdle ? .white.opacity(0.3) : accentColor.opacity(0.8))

                HStack(spacing: 10) {
                    Button { pomodoroViewModel.toggleRunning() } label: {
                        Image(systemName: pomodoroViewModel.state == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 0) {
                        Button {
                            if isIdle {
                                if workMinutes < 120 { workMinutes += 1 }
                            } else {
                                pomodoroViewModel.adjustTime(minutes: 1)
                            }
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 7, weight: .semibold))
                                .frame(width: 18, height: 11)
                        }
                        .buttonStyle(.plain).foregroundStyle(.white.opacity(0.5))
                        .contentShape(Rectangle())

                        Button {
                            if isIdle {
                                if workMinutes > 1 { workMinutes -= 1 }
                            } else {
                                pomodoroViewModel.adjustTime(minutes: -1)
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7, weight: .semibold))
                                .frame(width: 18, height: 11)
                        }
                        .buttonStyle(.plain).foregroundStyle(.white.opacity(0.5))
                        .contentShape(Rectangle())
                    }

                    Button { pomodoroViewModel.reset() } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 116, height: 116)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - OverviewAppPickerView

struct OverviewAppPickerView: View {
    @ObservedObject var store: PinnedAppsStore
    @StateObject private var allApps = AppLauncherStore()
    @State private var searchText = ""

    private var available: [URL] {
        let pinned = Set(store.apps.map(\.path))
        let base = allApps.apps.filter { !pinned.contains($0.path) }
        guard !searchText.isEmpty else { return base }
        let q = searchText.lowercased()
        return base.filter { $0.deletingPathExtension().lastPathComponent.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("", text: $searchText, prompt: Text(L10n.app("appLauncher.search", fallback: "Search apps")))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if allApps.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: 200)
            } else if available.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: searchText.isEmpty ? "checkmark.circle" : "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? L10n.app("appLauncher.allAdded", fallback: "All apps already added") : L10n.app("appLauncher.noMatch", fallback: "No matching apps found"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 64), spacing: 8)],
                        spacing: 10
                    ) {
                        ForEach(available, id: \.self) { url in
                            Button {
                                store.add(url)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                        .resizable().aspectRatio(contentMode: .fit)
                                        .frame(width: 36, height: 36)
                                    Text(url.deletingPathExtension().lastPathComponent)
                                        .font(.system(size: 9))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.primary)
                                        .frame(width: 58)
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                }
                .frame(height: 240)
            }

            Divider()

            HStack {
                Text(L10n.app("appLauncher.pinned", fallback: "Pinned \(store.apps.count) / 12 apps"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 300)
        .onAppear { allApps.loadIfNeeded() }
    }
}
