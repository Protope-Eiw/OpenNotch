import SwiftUI

struct InterfaceSettingsView: View {
    @ObservedObject var applicationSettings: ApplicationSettingsStore

    @AppStorage(AppStorageKeys.Overview.showApps)           private var showApps           = true
    @AppStorage(AppStorageKeys.Overview.showTimeDate)       private var showTimeDate       = true
    @AppStorage(AppStorageKeys.Overview.showSystemInfo)     private var showSystemInfo     = true
    @AppStorage(AppStorageKeys.Overview.showPomodoro)       private var showPomodoro       = true
    @AppStorage(AppStorageKeys.Overview.showWeather)        private var showWeather        = true
    @AppStorage(AppStorageKeys.Overview.hideAppNames)       private var hideAppNames       = false
    @AppStorage(AppStorageKeys.General.dashboardDefaultTab)      private var dashboardDefaultTab      = "last"
    @AppStorage(AppStorageKeys.General.dashboardTransitionStyle) private var dashboardTransitionStyle = DashboardTransitionStyle.slide.rawValue
    @AppStorage(AppStorageKeys.Music.showSkipButtons)            private var showSkipButtons         = true
    @AppStorage(AppStorageKeys.Music.showVisualizer)             private var showVisualizer          = true

    private func localized(_ key: String, fallback: String? = nil) -> String {
        applicationSettings.appLanguage.locale.dn(key, fallback: fallback)
    }

    private var enabledTabs: [DashboardTab] {
        DashboardTab.allCases.filter { !applicationSettings.dashboardDisabledTabs.contains($0.rawValue) }
    }

    private var defaultTabOptions: [String] {
        ["last"] + enabledTabs.map(\.rawValue)
    }

    private func defaultTabOptionTitle(_ value: String) -> String {
        if value == "last" { return localized("settings.interface.defaultTab.last", fallback: "Last Used") }
        switch DashboardTab(rawValue: value) {
        case .overview: return localized("settings.interface.defaultTab.overview", fallback: "Overview")
        case .music:    return localized("settings.interface.defaultTab.music", fallback: "Music")
        case .system:   return localized("settings.interface.defaultTab.system", fallback: "System")
        case .calendar: return localized("settings.interface.defaultTab.calendar", fallback: "Calendar")
        case .apps:     return localized("settings.interface.defaultTab.apps", fallback: "App Launcher")
        case nil:       return value
        }
    }

    var body: some View {
        SettingsPageScrollView {
            dashboardCard
        }
        .accessibilityIdentifier("settings.interface.root")
    }

    // MARK: - Dashboard Card

    private var dashboardCard: some View {
        SettingsCard(title: localized("settings.interface.dashboardCard", fallback: "Dashboard")) {
            SettingsSegmentedRow(
                title: localized("settings.interface.openMode", fallback: "Open Mode"),
                options: Array(DashboardOpenMode.allCases),
                optionTitle: { localized($0.title) },
                accessibilityIdentifier: "settings.general.dashboardOpenMode",
                selection: $applicationSettings.dashboardOpenMode
            )

            SettingsDivider()

            SettingsMenuRow(
                title: localized("settings.interface.defaultTab", fallback: "Default Tab"),
                description: localized("settings.interface.defaultTab.description", fallback: "Default tab opened when dashboard opens."),
                options: defaultTabOptions,
                optionTitle: { defaultTabOptionTitle($0) },
                accessibilityIdentifier: AppStorageKeys.General.dashboardDefaultTab,
                selection: $dashboardDefaultTab
            )

            SettingsDivider()

            SettingsSegmentedRow(
                title: localized("settings.interface.transitionStyle", fallback: "Transition Style"),
                description: localized("settings.interface.transitionStyle.description", fallback: "Slide: original swipe animation. Fade: prevents content overflow."),
                options: Array(DashboardTransitionStyle.allCases),
                optionTitle: { localized($0.title) },
                accessibilityIdentifier: AppStorageKeys.General.dashboardTransitionStyle,
                selection: Binding(
                    get: { DashboardTransitionStyle(rawValue: dashboardTransitionStyle) ?? .slide },
                    set: { dashboardTransitionStyle = $0.rawValue }
                )
            )

            SettingsDivider()

            Text(localized("settings.interface.visibleTabs", fallback: "Visible Tabs"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.top, 4)

            ForEach(DashboardTab.allCases, id: \.self) { tab in
                let tabEnabled = Binding<Bool>(
                    get: { !applicationSettings.dashboardDisabledTabs.contains(tab.rawValue) },
                    set: { isOn in
                        let wouldLeaveNone = !isOn &&
                            DashboardTab.allCases
                                .filter { !applicationSettings.dashboardDisabledTabs.contains($0.rawValue) }
                                .count <= 1
                        guard !wouldLeaveNone else { return }
                        if isOn {
                            applicationSettings.dashboardDisabledTabs.remove(tab.rawValue)
                        } else {
                            applicationSettings.dashboardDisabledTabs.insert(tab.rawValue)
                            if dashboardDefaultTab == tab.rawValue {
                                dashboardDefaultTab = "last"
                            }
                        }
                    }
                )

                SettingsDivider(indented: true)

                SettingsToggleRow(
                    title: localized(tab.title),
                    systemImage: tab.icon,
                    color: tab.settingsColor,
                    isOn: tabEnabled,
                    accessibilityIdentifier: "settings.dashboard.tab.\(tab.rawValue)"
                )

                if tab == .overview, tabEnabled.wrappedValue {
                    overviewSubSettings
                }
                if tab == .music, tabEnabled.wrappedValue {
                    musicSubSettings
                }
            }
        }
    }

    // MARK: - Music sub-settings

    private var musicSubSettings: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.4).padding(.leading, 43)
            SubToggleRow(
                title: localized("settings.interface.music.skipButtons", fallback: "Skip Buttons"),
                isOn: $showSkipButtons,
                accessibilityIdentifier: AppStorageKeys.Music.showSkipButtons
            )

            Divider().opacity(0.4).padding(.leading, 43)
            SubToggleRow(
                title: localized("settings.interface.music.visualizer", fallback: "Audio Visualizer"),
                isOn: $showVisualizer,
                accessibilityIdentifier: AppStorageKeys.Music.showVisualizer
            )
        }
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.leading, 16)
        .padding(.top, 2)
    }

    // MARK: - Overview sub-settings (shown when Overview tab is enabled)

    private var overviewSubSettings: some View {
        VStack(spacing: 0) {
            // App launcher
            Divider().opacity(0.4).padding(.leading, 56)
            SettingsToggleRow(
                title: localized("settings.interface.overview.apps", fallback: "App Launcher"),
                systemImage: "square.grid.2x2.fill",
                color: .blue,
                isOn: $showApps,
                accessibilityIdentifier: AppStorageKeys.Overview.showApps
            )
            .padding(.leading, 16)

            if showApps {
                Divider().opacity(0.3).padding(.leading, 72)
                SubToggleRow(
                    title: localized("settings.interface.overview.hideAppNames", fallback: "Hide App Names"),
                    isOn: $hideAppNames,
                    accessibilityIdentifier: AppStorageKeys.Overview.hideAppNames
                )
                .padding(.leading, 32)

                Divider().opacity(0.3).padding(.leading, 72)
                PinnedAppsSettingsRow(
                    title: localized("settings.interface.pinnedApps.title", fallback: "Pinned Apps"),
                    description: localized("settings.interface.pinnedApps.description", fallback: "Quick-access apps in the overview."),
                    addButton: localized("settings.interface.pinnedApps.add", fallback: "Add"),
                    pickerTitle: localized("settings.interface.pinnedApps.pickerTitle", fallback: "Choose an App"),
                    doneButton: localized("settings.interface.pinnedApps.done", fallback: "Done")
                )
                    .padding(.leading, 32)
                    .padding(.vertical, 2)
            }

            // Time & date
            Divider().opacity(0.4).padding(.leading, 56)
            SettingsToggleRow(
                title: localized("settings.interface.overview.timeDate", fallback: "Time & Date"),
                systemImage: "clock.fill",
                color: .orange,
                isOn: $showTimeDate,
                accessibilityIdentifier: AppStorageKeys.Overview.showTimeDate
            )
            .padding(.leading, 16)

            if showTimeDate {
                Divider().opacity(0.3).padding(.leading, 72)
                SubToggleRow(
                    title: localized("settings.interface.overview.weather", fallback: "Weather"),
                    isOn: $showWeather,
                    accessibilityIdentifier: AppStorageKeys.Overview.showWeather
                )
                .padding(.leading, 32)
            }

            // System info
            Divider().opacity(0.4).padding(.leading, 56)
            SettingsToggleRow(
                title: localized("settings.interface.overview.systemInfo", fallback: "System Info"),
                systemImage: "cpu.fill",
                color: .green,
                isOn: $showSystemInfo,
                accessibilityIdentifier: AppStorageKeys.Overview.showSystemInfo
            )
            .padding(.leading, 16)

            // Pomodoro
            Divider().opacity(0.4).padding(.leading, 56)
            SettingsToggleRow(
                title: localized("settings.interface.overview.pomodoro", fallback: "Pomodoro"),
                systemImage: "timer",
                color: .red,
                isOn: $showPomodoro,
                accessibilityIdentifier: AppStorageKeys.Overview.showPomodoro
            )
            .padding(.leading, 16)

            if showPomodoro {
                Divider().opacity(0.3).padding(.leading, 72)
                HStack {
                    Text(localized("settings.interface.overview.workDuration", fallback: "Work Duration"))
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(applicationSettings.appLanguage.locale.dnFormat("settings.interface.overview.workDurationValue", fallback: "%lld min", Int64(applicationSettings.overviewPomodoroDuration)))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Stepper("", value: $applicationSettings.overviewPomodoroDuration, in: 1...120)
                        .labelsHidden()
                }
                .padding(.leading, 32)
                .padding(.trailing, 4)
                .padding(.vertical, 6)
            }
        }
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.leading, 16)
        .padding(.top, 2)
    }
}

// MARK: - Sub-level Toggle Row (no icon)

private struct SubToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var accessibilityIdentifier: String? = nil

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .center, spacing: 0) {
                Text(title)
                Spacer()
            }
            .frame(minHeight: 40)
        }
        .toggleStyle(CustomToggleStyle())
        .modifier(SettingsAccessibilityModifier(identifier: accessibilityIdentifier))
    }
}

// MARK: - Pinned Apps Settings Row

private struct PinnedAppsSettingsRow: View {
    let title: String
    let description: String
    let addButton: String
    let pickerTitle: String
    let doneButton: String

    @StateObject private var store = PinnedAppsStore()
    @StateObject private var allAppsStore = AppLauncherStore()
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .frame(width: 28, height: 28)
                    .background(Color.teal.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .foregroundStyle(.teal)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(addButton) {
                    allAppsStore.loadIfNeeded()
                    showingPicker = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.blue)
            }

            if !store.apps.isEmpty {
                VStack(spacing: 0) {
                    ForEach(store.apps, id: \.self) { url in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable().aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            Text(url.deletingPathExtension().lastPathComponent)
                                .font(.system(size: 12))
                            Spacer()
                            Button {
                                store.remove(url)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        if url != store.apps.last {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 8)
        .onReceive(NotificationCenter.default.publisher(for: .pinnedAppsDidChange)) { _ in
            store.load()
        }
        .sheet(isPresented: $showingPicker) {
            appPickerContent
        }
    }

    private var appPickerContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text(pickerTitle).font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(doneButton) { showingPicker = false }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            if allAppsStore.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let available = allAppsStore.apps.filter { !store.apps.contains($0) }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 12)], spacing: 16) {
                        ForEach(available, id: \.self) { url in
                            Button {
                                store.add(url)
                                if store.apps.count >= 12 { showingPicker = false }
                            } label: {
                                VStack(spacing: 5) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                        .resizable().aspectRatio(contentMode: .fit)
                                        .frame(width: 44, height: 44)
                                    Text(url.deletingPathExtension().lastPathComponent)
                                        .font(.system(size: 9)).lineLimit(1).frame(maxWidth: 74)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 420, height: 340)
    }
}
