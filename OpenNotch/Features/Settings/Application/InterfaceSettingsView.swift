import SwiftUI

struct InterfaceSettingsView: View {
    @ObservedObject var applicationSettings: ApplicationSettingsStore

    @AppStorage("settings.overview.showApps")       private var showApps       = true
    @AppStorage("settings.overview.showTimeDate")   private var showTimeDate   = true
    @AppStorage("settings.overview.showSystemInfo") private var showSystemInfo = true
    @AppStorage("settings.overview.showPomodoro")   private var showPomodoro   = true
    @AppStorage("settings.overview.showWeather")    private var showWeather    = true
    @AppStorage("settings.overview.hideAppNames")   private var hideAppNames   = false

    var body: some View {
        SettingsPageScrollView {
            dashboardCard
        }
        .accessibilityIdentifier("settings.interface.root")
    }

    // MARK: - Dashboard Card

    private var dashboardCard: some View {
        SettingsCard(title: "仪表盘") {
            SettingsMenuRow(
                title: "打开方式",
                options: Array(DashboardOpenMode.allCases),
                optionTitle: { $0.title },
                accessibilityIdentifier: "settings.general.dashboardOpenMode",
                selection: $applicationSettings.dashboardOpenMode
            )

            Divider().opacity(0.6)

            Text("可见标签")
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
                        }
                    }
                )

                Divider().opacity(0.6).padding(.leading, 43)

                SettingsToggleRow(
                    title: tab.title,
                    systemImage: tab.icon,
                    color: tab.settingsColor,
                    isOn: tabEnabled,
                    accessibilityIdentifier: "settings.dashboard.tab.\(tab.rawValue)"
                )

                if tab == .overview, tabEnabled.wrappedValue {
                    overviewSubSettings
                }
            }
        }
    }

    // MARK: - Overview sub-settings (shown when Overview tab is enabled)

    private var overviewSubSettings: some View {
        VStack(spacing: 0) {
            // App launcher
            Divider().opacity(0.4).padding(.leading, 56)
            SettingsToggleRow(
                title: "应用快速启动",
                systemImage: "square.grid.2x2.fill",
                color: .blue,
                isOn: $showApps,
                accessibilityIdentifier: "settings.overview.showApps"
            )
            .padding(.leading, 16)

            if showApps {
                Divider().opacity(0.3).padding(.leading, 72)
                SubToggleRow(
                    title: "隐藏应用名称",
                    isOn: $hideAppNames,
                    accessibilityIdentifier: "settings.overview.hideAppNames"
                )
                .padding(.leading, 32)

                Divider().opacity(0.3).padding(.leading, 72)
                PinnedAppsSettingsRow()
                    .padding(.leading, 32)
                    .padding(.vertical, 2)
            }

            // Time & date
            Divider().opacity(0.4).padding(.leading, 56)
            SettingsToggleRow(
                title: "时间与日期",
                systemImage: "clock.fill",
                color: .orange,
                isOn: $showTimeDate,
                accessibilityIdentifier: "settings.overview.showTimeDate"
            )
            .padding(.leading, 16)

            if showTimeDate {
                Divider().opacity(0.3).padding(.leading, 72)
                SubToggleRow(
                    title: "天气",
                    isOn: $showWeather,
                    accessibilityIdentifier: "settings.overview.showWeather"
                )
                .padding(.leading, 32)
            }

            // System info
            Divider().opacity(0.4).padding(.leading, 56)
            SettingsToggleRow(
                title: "系统信息",
                systemImage: "cpu.fill",
                color: .green,
                isOn: $showSystemInfo,
                accessibilityIdentifier: "settings.overview.showSystemInfo"
            )
            .padding(.leading, 16)

            // Pomodoro
            Divider().opacity(0.4).padding(.leading, 56)
            SettingsToggleRow(
                title: "番茄计时器",
                systemImage: "timer",
                color: .red,
                isOn: $showPomodoro,
                accessibilityIdentifier: "settings.overview.showPomodoro"
            )
            .padding(.leading, 16)

            if showPomodoro {
                Divider().opacity(0.3).padding(.leading, 72)
                HStack {
                    Text("工作时长")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("\(applicationSettings.overviewPomodoroDuration) 分钟")
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
    let title: LocalizedStringKey
    @Binding var isOn: Bool
    var accessibilityIdentifier: String? = nil

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .center, spacing: 0) {
                Text(title)
                Spacer()
            }
            .frame(minHeight: 30)
        }
        .toggleStyle(CustomToggleStyle())
        .modifier(SettingsAccessibilityModifier(identifier: accessibilityIdentifier))
    }
}

// MARK: - Pinned Apps Settings Row

private struct PinnedAppsSettingsRow: View {
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
                    Text("快速启动应用")
                        .font(.system(size: 13, weight: .medium))
                    Text("在概览网格中显示的应用。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("添加") {
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
                Text("选择应用").font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("完成") { showingPicker = false }
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
