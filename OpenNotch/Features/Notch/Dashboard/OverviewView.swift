import SwiftUI
import Combine
import EventKit

struct OverviewView: View {
    @ObservedObject var systemMonitorViewModel: SystemMonitorViewModel
    @ObservedObject var pomodoroViewModel: PomodoroViewModel

    @AppStorage(AppStorageKeys.Overview.showApps)         private var showApps       = true
    @AppStorage(AppStorageKeys.Overview.showTimeDate)     private var showTimeDate   = true
    @AppStorage(AppStorageKeys.Overview.showSystemInfo)   private var showSystemInfo = true
    @AppStorage(AppStorageKeys.Overview.showPomodoro)     private var showPomodoro   = true
    @AppStorage(AppStorageKeys.Overview.hideAppNames)     private var hideAppNames   = false
    @AppStorage(AppStorageKeys.Overview.showWeather)      private var showWeather    = false
    @AppStorage(AppStorageKeys.Overview.pomodoroDuration) private var workMinutes    = 25

    @StateObject private var pinnedAppsStore = PinnedAppsStore()
    @StateObject private var weatherService  = WeatherService()
    @StateObject private var calendarStore   = CalendarStore()
    @State private var now = Date()
    @State private var showAppPicker = false
    @State private var lastCalendarRefreshMinute: Int?

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            if showApps {
                appsColumn
                if showTimeDate || showWeather || showSystemInfo || showPomodoro { columnDivider }
            }
            if showTimeDate {
                timeDateColumn
                if showWeather || showSystemInfo || showPomodoro { columnDivider }
            }
            if showWeather {
                weatherColumn
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
        .onReceive(clock) { date in
            now = date
            refreshUpcomingScheduleIfNeeded(for: date)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pinnedAppsDidChange)) { _ in
            pinnedAppsStore.load()
        }
        .onAppear {
            if showWeather { weatherService.requestAndFetch() }
            if showTimeDate { calendarStore.loadUpcoming() }
        }
        .onChange(of: showWeather) { _, on in
            if on { weatherService.requestAndFetch() }
        }
        .onChange(of: showTimeDate) { _, on in
            if on { calendarStore.loadUpcoming() }
        }
        .onChange(of: showAppPicker) { _, isPresented in
            NotificationCenter.default.post(
                name: .dashboardPopoverPresentationDidChange,
                object: nil,
                userInfo: ["isPresented": isPresented]
            )
        }
        .onDisappear {
            NotificationCenter.default.post(
                name: .dashboardPopoverPresentationDidChange,
                object: nil,
                userInfo: ["isPresented": false]
            )
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

            if shouldShowLunarDate, let lunarDateText {
                HStack(spacing: 3) {
                    Image(systemName: "moonphase.waxing.crescent")
                        .font(.system(size: 9))
                    Text(lunarDateText)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(0.34))
            }

            if let nextScheduleText {
                HStack(spacing: 3) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 9))
                    Text(nextScheduleText)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .foregroundStyle(.white.opacity(0.34))
            }

        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var weatherColumn: some View {
        VStack(spacing: 4) {
            if let temp = weatherService.temperature {
                Image(systemName: weatherService.symbolName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.orange.opacity(0.9))

                Text(String(format: "%.0f\u{00B0}", temp))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if !weatherService.conditionText.isEmpty {
                    Text(weatherService.conditionText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.34))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else if weatherService.fetchFailed {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.18))
                Text(L10n.app("weather.unavailable", fallback: "Weather unavailable"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.24))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                Text(L10n.app("weather.fetching", fallback: "Fetching weather\u{2026}"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.24))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shouldShowLunarDate: Bool {
        let identifier = L10n.appLanguageIdentifier
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        return identifier == "zh"
            || identifier.hasPrefix("zh-hans")
            || identifier.hasPrefix("zh-cn")
            || identifier.hasPrefix("zh-sg")
    }

    private var lunarDateText: String? {
        var calendar = Calendar(identifier: .chinese)
        calendar.locale = Locale(identifier: "zh-Hans")
        let components = calendar.dateComponents([.month, .day, .isLeapMonth], from: now)
        guard let month = components.month, let day = components.day,
              (1...12).contains(month), (1...30).contains(day) else {
            return nil
        }

        let months = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]
        let days = [
            "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
        ]
        let leapPrefix = components.isLeapMonth == true ? "闰" : ""
        return "农历 \(leapPrefix)\(months[month - 1])\(days[day - 1])"
    }

    private var nextScheduleText: String? {
        guard let event = calendarStore.upcomingEvents.first else { return nil }
        let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = (title?.isEmpty == false) ? title! : L10n.app("calendar.untitledEvent", fallback: "Untitled")
        return "\(scheduleStartText(for: event)) \(resolvedTitle)"
    }

    private func scheduleStartText(for event: EKEvent) -> String {
        if event.isAllDay {
            return L10n.app("calendar.allDay", fallback: "All-day")
        }

        guard let date = event.startDate else {
            return L10n.app("calendar.upcoming", fallback: "Upcoming")
        }
        let calendar = Calendar.current
        let time = date.formatted(.dateTime.hour().minute())
        if calendar.isDateInToday(date) {
            return time
        }
        if calendar.isDateInTomorrow(date) {
            return "\(L10n.app("calendar.tomorrow", fallback: "Tomorrow")) \(time)"
        }
        return date.formatted(.dateTime.month().day().hour().minute())
    }

    private func refreshUpcomingScheduleIfNeeded(for date: Date) {
        guard showTimeDate else { return }
        let minute = Calendar.current.component(.minute, from: date)
        guard lastCalendarRefreshMinute != minute else { return }
        lastCalendarRefreshMinute = minute
        calendarStore.loadUpcoming()
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
            VStack(alignment: .leading, spacing: 2) {
                resourceDetailRow(
                    systemName: "memorychip",
                    text: "\(systemMonitorViewModel.memoryUsedText) / \(systemMonitorViewModel.memoryTotalText)"
                )
                resourceDetailRow(
                    systemName: "internaldrive",
                    text: "\(systemMonitorViewModel.diskUsedText) / \(systemMonitorViewModel.diskTotalText)"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            openActivityMonitor()
        }
        .help("Open Activity Monitor")
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

    private func resourceDetailRow(systemName: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemName)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(.white.opacity(0.3))
    }

    private func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.open(url)
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
                        PomodoroAdjustButton(systemName: "chevron.up") {
                            adjustPomodoro(isIdle: isIdle, direction: 1)
                        }

                        PomodoroAdjustButton(systemName: "chevron.down") {
                            adjustPomodoro(isIdle: isIdle, direction: -1)
                        }
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
        .clipped()
    }

    private func adjustPomodoro(isIdle: Bool, direction: Int) {
        if isIdle {
            let step = 1
            workMinutes = min(120, max(1, workMinutes + direction * step))
            pomodoroViewModel.syncWorkMinutes()
        } else {
            pomodoroViewModel.adjustTime(minutes: direction)
        }
    }
}

private struct PomodoroAdjustButton: View {
    let systemName: String
    let action: () -> Void

    @State private var isPressing = false
    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 7, weight: .semibold))
            .foregroundStyle(.white.opacity(isPressing ? 0.85 : 0.5))
            .frame(width: 22, height: 14)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressing else { return }
                        isPressing = true
                        action()
                        startRepeating()
                    }
                    .onEnded { _ in
                        stopRepeating()
                    }
            )
            .onDisappear {
                stopRepeating()
            }
    }

    private func startRepeating() {
        repeatTask?.cancel()
        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            while !Task.isCancelled {
                action()
                try? await Task.sleep(for: .milliseconds(140))
            }
        }
    }

    private func stopRepeating() {
        isPressing = false
        repeatTask?.cancel()
        repeatTask = nil
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
