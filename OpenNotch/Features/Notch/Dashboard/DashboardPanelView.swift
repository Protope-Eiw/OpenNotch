import SwiftUI

struct DashboardPanelView: View {
    @ObservedObject var systemMonitorViewModel: SystemMonitorViewModel
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @ObservedObject var pomodoroViewModel: PomodoroViewModel
    @Binding var selectedTab: DashboardTab
    @Binding var appSearchText: String
    var enabledTabs: [DashboardTab]

    @State private var macInfo: MacSystemInfo? = nil

    private var selectedIndex: Int {
        enabledTabs.firstIndex(of: selectedTab) ?? 0
    }

    var body: some View {
        pageContent
            .task { if macInfo == nil { macInfo = await MacSystemInfo.load() } }
            .background(
                SwipeEventMonitor(
                    onSwipeLeft: {
                        let idx = selectedIndex
                        guard idx + 1 < enabledTabs.count else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedTab = enabledTabs[idx + 1]
                        }
                    },
                    onSwipeRight: {
                        let idx = selectedIndex
                        guard idx > 0 else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedTab = enabledTabs[idx - 1]
                        }
                    }
                )
            )
    }

    private var pageContent: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(enabledTabs, id: \.self) { tab in
                    if tab == selectedTab {
                        tabPage(for: tab)
                            .frame(width: geo.size.width)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
        }
        .mask(Rectangle())
    }

    @ViewBuilder
    private func tabPage(for tab: DashboardTab) -> some View {
        switch tab {
        case .overview: OverviewView(systemMonitorViewModel: systemMonitorViewModel, pomodoroViewModel: pomodoroViewModel)
        case .music:    musicView
        case .system:   systemView
        case .calendar: CalendarTabView()
        case .apps:     AppLauncherView(searchText: $appSearchText)
        }
    }

    // MARK: Music tab

    private var musicView: some View {
        Group {
            if let snapshot = nowPlayingViewModel.snapshot {
                MusicPlayerView(
                    snapshot: snapshot,
                    artwork: nowPlayingViewModel.artworkImage,
                    onPlayPause:   { nowPlayingViewModel.togglePlayPause() },
                    onPrev:        { nowPlayingViewModel.previousTrack() },
                    onNext:        { nowPlayingViewModel.nextTrack() },
                    onShuffle:     { nowPlayingViewModel.toggleShuffle() },
                    onRepeat:      { nowPlayingViewModel.toggleRepeat() },
                    onSeek:        { nowPlayingViewModel.seek(to: $0) },
                    onSkipBack:    { nowPlayingViewModel.skip(seconds: -15) },
                    onSkipForward: { nowPlayingViewModel.skip(seconds: 15) }
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Nothing playing")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            nowPlayingViewModel.setDetailedPresentationActive(true, source: "dashboard.music")
        }
        .onDisappear {
            nowPlayingViewModel.setDetailedPresentationActive(false, source: "dashboard.music")
        }
    }

    // MARK: System tab

    private var systemView: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    gaugeCard(title: "CPU",
                              value: systemMonitorViewModel.cpuUsage,
                              valueText: "\(Int(systemMonitorViewModel.cpuUsage))%",
                              color: Color.thresholdColor(systemMonitorViewModel.cpuUsage, warn: 50, danger: 80))
                    gaugeCard(title: "MEM",
                              value: systemMonitorViewModel.memoryUsage,
                              valueText: "\(Int(systemMonitorViewModel.memoryUsage))%",
                              color: Color.thresholdColor(systemMonitorViewModel.memoryUsage, warn: 70, danger: 85))
                    speedCard(sfSymbol: "arrow.up",
                              speed: systemMonitorViewModel.uploadSpeed,
                              label: "Upload")
                }
                HStack(spacing: 7) {
                    gaugeCard(title: "DISK",
                              value: systemMonitorViewModel.diskUsage,
                              valueText: "\(Int(systemMonitorViewModel.diskUsage))%",
                              color: Color.thresholdColor(systemMonitorViewModel.diskUsage, warn: 80, danger: 90))
                    gaugeCard(title: systemMonitorViewModel.isCharging ? "BAT\u{26A1}" : "BAT",
                              value: Double(systemMonitorViewModel.batteryLevel),
                              valueText: "\(systemMonitorViewModel.batteryLevel)%",
                              color: Color.batteryColor(systemMonitorViewModel.batteryLevel,
                                                  isCharging: systemMonitorViewModel.isCharging))
                    speedCard(sfSymbol: "arrow.down",
                              speed: systemMonitorViewModel.downloadSpeed,
                              label: "Download")
                }
            }
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                Text(macInfo?.modelName ?? "Mac")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                macInfoRow("cpu",        macInfo?.chipName     ?? "\u{2013}")
                macInfoRow("memorychip", macInfo?.ramText      ?? "\u{2013}")
                macInfoRow("barcode",    macInfo?.serialNumber ?? "\u{2013}")
                macInfoRow("apple.logo", macInfo?.macOSVersion ?? "\u{2013}")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func gaugeCard(title: String, value: Double, valueText: String, color: Color) -> some View {
        ProgressRing(progress: value, color: color, label: title, valueText: valueText)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func speedCard(sfSymbol: String, speed: Double, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: sfSymbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.netSpeedColor(speed))
            Text(systemMonitorViewModel.formattedSpeed(speed))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.netSpeedColor(speed))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func macInfoRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 13)
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
        }
    }
}
