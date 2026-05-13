import SwiftUI

struct DashboardPanelView: View {
    @ObservedObject var systemMonitorViewModel: SystemMonitorViewModel
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @ObservedObject var pomodoroViewModel: PomodoroViewModel
    @Binding var selectedTab: DashboardTab
    @Binding var appSearchText: String
    var enabledTabs: [DashboardTab]

    @State private var macInfo: MacSystemInfo? = nil
    @AppStorage(AppStorageKeys.General.dashboardTransitionStyle) private var transitionStyle = DashboardTransitionStyle.slide.rawValue

    private var transitionAnimation: Animation {
        transitionStyle == DashboardTransitionStyle.fade.rawValue
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.35, dampingFraction: 0.85)
    }

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
                        withAnimation(transitionAnimation) {
                            selectedTab = enabledTabs[idx + 1]
                        }
                    },
                    onSwipeRight: {
                        let idx = selectedIndex
                        guard idx > 0 else { return }
                        withAnimation(transitionAnimation) {
                            selectedTab = enabledTabs[idx - 1]
                        }
                    }
                )
            )
    }

    @ViewBuilder
    private var pageContent: some View {
        if transitionStyle == DashboardTransitionStyle.fade.rawValue {
            fadeContent
        } else {
            slideContent
        }
    }

    private var fadeContent: some View {
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
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .mask(Rectangle())
    }

    private var slideContent: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(enabledTabs, id: \.self) { tab in
                    tabPage(for: tab)
                        .frame(width: geo.size.width)
                        .clipShape(Rectangle())
                        .offset(x: slideOffset(for: tab, width: geo.size.width))
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: slideOffset(for: tab, width: geo.size.width))
                }
            }
        }
    }

    private func slideOffset(for tab: DashboardTab, width: CGFloat) -> CGFloat {
        guard let tabIdx = enabledTabs.firstIndex(of: tab),
              let selIdx = enabledTabs.firstIndex(of: selectedTab) else { return 0 }
        return CGFloat(tabIdx - selIdx) * width
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
        HStack(spacing: 0) {
            SWRingChart(
                data: [
                    .init(label: "CPU", value: systemMonitorViewModel.cpuUsage, color: Color.green),
                    .init(label: "MEM", value: systemMonitorViewModel.memoryUsage, color: .orange),
                    .init(label: "DSK", value: systemMonitorViewModel.diskUsage, color: .cyan),
                ],
                maxValue: 100,
                size: 140,
                ringWidth: 12,
                spacing: 6,
                showLegend: false
            ) {
                VStack(spacing: 0) {
                    Text("CPU \(Int(systemMonitorViewModel.cpuUsage))%").foregroundStyle(Color.green)
                    Text("MEM \(Int(systemMonitorViewModel.memoryUsage))%").foregroundStyle(Color.orange)
                    Text("DSK \(Int(systemMonitorViewModel.diskUsage))%").foregroundStyle(Color.cyan)
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .frame(width: 140, height: 150)
            .padding(.leading, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
