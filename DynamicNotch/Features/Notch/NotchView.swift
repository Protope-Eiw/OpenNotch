import SwiftUI
import Combine
internal import AppKit
import UniformTypeIdentifiers
import EventKit

struct NotchView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var notchViewModel: NotchViewModel
    @ObservedObject var notchEventCoordinator: NotchEventCoordinator
    @ObservedObject var powerViewModel: PowerViewModel
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var downloadViewModel: DownloadViewModel
    @ObservedObject var focusViewModel: FocusViewModel
    @ObservedObject var airDropViewModel: AirDropNotchViewModel
    @ObservedObject var airDropController: NotchAirDropController
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @ObservedObject var timerViewModel: TimerViewModel
    @ObservedObject var screenRecordingViewModel: ScreenRecordingViewModel
    @ObservedObject var lockScreenManager: LockScreenManager
    @ObservedObject var systemMonitorViewModel: SystemMonitorViewModel

    @State private var dashboardOpen = false
    @State private var dashboardTab: DashboardTab = .system
    @State private var pillHovered = false
    @State private var notchHovered = false
    @State private var dashboardHoverTask: Task<Void, Never>? = nil
    private let pillExpandExtra: CGFloat = 80

    var body: some View {
        ZStack(alignment: .top) {
            pillStrip.offset(y: 1)

            notchBody
                .environment(\.notchScale, notchViewModel.notchModel.scale)
                .background(
                    NotchEventHandlersView(
                        notchEventCoordinator: notchEventCoordinator,
                        powerViewModel: powerViewModel,
                        bluetoothViewModel: bluetoothViewModel,
                        networkViewModel: networkViewModel,
                        downloadViewModel: downloadViewModel,
                        focusViewModel: focusViewModel,
                        airDropViewModel: airDropViewModel,
                        settingsViewModel: settingsViewModel,
                        nowPlayingViewModel: nowPlayingViewModel,
                        timerViewModel: timerViewModel,
                        screenRecordingViewModel: screenRecordingViewModel,
                        lockScreenManager: lockScreenManager
                    )
                )
                .overlay {
                    DragAndDropDestinationView(
                        isTargeted: $airDropController.isTargeted,
                        targetedDropTarget: Binding(
                            get: { airDropViewModel.targetedDropTarget },
                            set: { airDropViewModel.setTargetedDropTarget($0) }
                        ),
                        mode: settingsViewModel.mediaAndFiles.dragAndDropActivityMode,
                        onDropPasteboard: { target, pasteboard in
                            switch target {
                            case .airDrop:
                                guard settingsViewModel.mediaAndFiles.dragAndDropActivityMode.showsAirDrop else {
                                    return false
                                }

                                return airDropController.handlePasteboardDrop(pasteboard)
                            case .tray:
                                guard settingsViewModel.mediaAndFiles.dragAndDropActivityMode.showsTray else {
                                    return false
                                }

                                return airDropController.handleTrayDrop(pasteboard)
                            }
                        }
                    )
                }
                .onChange(of: notchViewModel.notchModel.content?.id) {
                    notchViewModel.handleStrokeVisibility()
                }
                .onChange(of: settingsViewModel.notchWidth) {
                    notchViewModel.updateDimensions()
                }
                .onChange(of: settingsViewModel.notchHeight) {
                    notchViewModel.updateDimensions()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private extension NotchView {
    var baseWidth:  CGFloat { notchViewModel.notchModel.baseWidth  > 0 ? notchViewModel.notchModel.baseWidth  : 170 }
    var baseHeight: CGFloat { notchViewModel.notchModel.baseHeight > 0 ? notchViewModel.notchModel.baseHeight : 37  }

    // Sizing — update leftIntrinsicWidth or rightIntrinsicWidth to add more content
    var ringSize:       CGFloat { baseHeight - 6 }
    var outerPad:       CGFloat { 10 }
    var notchClearance: CGFloat { ceil(notchViewModel.interactiveCornerRadius.top) + 3 }
    var leftIntrinsicWidth:  CGFloat { outerPad + 65 }   // two-line speed text ~65pt wide
    var rightIntrinsicWidth: CGFloat { notchClearance + ringSize + 8 + ringSize + outerPad }
    var sideWidth: CGFloat { max(leftIntrinsicWidth, rightIntrinsicWidth) }
    var activeSideWidth: CGFloat { dashboardOpen ? sideWidth + pillExpandExtra : sideWidth }

    // One unified black strip: [left content | notch bridge | right content]
    // The notch body renders on top — the bridge section is invisible (black on black).
    var pillStrip: some View {
        let notchBridgeWidth = max(0,
            notchViewModel.presentedNotchSize.width - 2 * notchViewModel.interactiveCornerRadius.top
        )
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left: two-line speed text, colour-coded by rate
                HStack(spacing: 0) {
                    Color.clear.frame(width: outerPad)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrowtriangle.up.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(systemMonitorViewModel.formattedSpeed(systemMonitorViewModel.uploadSpeed))
                                .foregroundStyle(speedColor(systemMonitorViewModel.uploadSpeed))
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(systemMonitorViewModel.formattedSpeed(systemMonitorViewModel.downloadSpeed))
                                .foregroundStyle(speedColor(systemMonitorViewModel.downloadSpeed))
                        }
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    Spacer(minLength: 0)
                }
                .frame(width: activeSideWidth, height: baseHeight)
                .contentShape(Rectangle())
                .onTapGesture { toggleDashboard() }

                // Bridge: hidden under the notch — notch body handles its own tap
                Color.clear.frame(width: notchBridgeWidth, height: baseHeight)

                // Right: CPU + MEM rings
                HStack(spacing: 0) {
                    Color.clear.frame(width: notchClearance)
                    ProgressRing(
                        progress: systemMonitorViewModel.cpuUsage,
                        color: pillColor(systemMonitorViewModel.cpuUsage, warn: 50, danger: 80),
                        label: "CPU"
                    )
                    .frame(width: ringSize, height: ringSize)
                    Color.clear.frame(width: 8)
                    ProgressRing(
                        progress: systemMonitorViewModel.memoryUsage,
                        color: pillColor(systemMonitorViewModel.memoryUsage, warn: 70, danger: 85),
                        label: "MEM"
                    )
                    .frame(width: ringSize, height: ringSize)
                    Color.clear.frame(width: outerPad)
                }
                .frame(width: activeSideWidth, height: baseHeight)
                .contentShape(Rectangle())
                .onTapGesture { toggleDashboard() }
            }

            if dashboardOpen {
                DashboardPanelView(
                    systemMonitorViewModel: systemMonitorViewModel,
                    nowPlayingViewModel: nowPlayingViewModel,
                    selectedTab: $dashboardTab
                )
                .frame(height: 210)
                .transition(.opacity)
            }
        }
        .background(Color.black)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: dashboardOpen ? 16 : 9,
            bottomTrailingRadius: dashboardOpen ? 16 : 9,
            topTrailingRadius: 0
        ))
        .contentShape(Rectangle())
        .onHover { hovering in
            pillHovered = hovering
            handleHoverChange()
        }
    }

    private func toggleDashboard() {
        dashboardHoverTask?.cancel()
        dashboardHoverTask = nil
        let animation: Animation = dashboardOpen
            ? .spring(response: 0.45, dampingFraction: 1.0)
            : .spring(response: 0.42, dampingFraction: 0.8)
        withAnimation(animation) {
            dashboardOpen.toggle()
        }
    }

    private func handleHoverChange() {
        let hovered = pillHovered || notchHovered
        dashboardHoverTask?.cancel()

        if !hovered {
            dashboardHoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 1.0)) {
                    dashboardOpen = false
                }
            }
            return
        }

        guard settingsViewModel.application.dashboardOpenMode == .hover else { return }

        dashboardHoverTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                dashboardOpen = true
            }
        }
    }

    func pillColor(_ v: Double, warn: Double, danger: Double) -> Color {
        v >= danger ? .red : v >= warn ? .orange : .green.opacity(0.9)
    }

    // Speed colour: green(idle) → cyan → blue → orange → red(saturated)
    func speedColor(_ bytesPerSec: Double) -> Color {
        switch bytesPerSec {
        case ..<100_000:          return .white.opacity(0.6)   // < 100 KB/s  idle
        case ..<1_000_000:        return .green                // < 1 MB/s
        case ..<5_000_000:        return .cyan                 // < 5 MB/s
        case ..<20_000_000:       return .yellow               // < 20 MB/s
        default:                  return .orange               // ≥ 20 MB/s  heavy
        }
    }

    @ViewBuilder
    var notchBody: some View {
        notchSurface
            .overlay {
                contentOverlay
                    .clipShape(
                        NotchShape(
                            topCornerRadius: notchViewModel.interactiveCornerRadius.top,
                            bottomCornerRadius: notchViewModel.interactiveCornerRadius.bottom
                        )
                    )
            }
            .shadow(
                color: notchViewModel.isDisplayingExpandedLiveActivity ? .black.opacity(0.5) : .clear,
                radius: 15
            )
            .frame(
                width: notchViewModel.presentedNotchSize.width,
                height: notchViewModel.presentedNotchSize.height
            )
            .customNotchPressable(
                notchViewModel: notchViewModel,
                isPressed: $notchViewModel.isPressed,
                baseSize: notchViewModel.presentedNotchSize
            )
            .offset(y: 1)
            .customNotchMouseSwipeable(
                notchViewModel: notchViewModel,
                isEnabled: shouldEnableNotchSwipeGestures
            )
            .customNotchSwipeDismissable(
                notchViewModel: notchViewModel,
                isEnabled: shouldEnableNotchSwipeGestures
            )
            .contextMenu {
                contextMenuItem
            }
            .environment(\.colorScheme, .dark)
            .animation(notchViewModel.animations.strokeVisibility, value: settingsViewModel.isShowNotchStrokeEnabled)
            .animation(notchViewModel.animations.notchVisibility, value: notchViewModel.showNotch)
            .simultaneousGesture(TapGesture().onEnded { toggleDashboard() })
            .onHover { hovering in
                notchHovered = hovering
                handleHoverChange()
            }
    }
    
    var shouldEnableNotchSwipeGestures: Bool {
        guard !notchViewModel.isActivityPresentationHidden else { return false }
        
        return !(
            notchViewModel.notchModel.isPresentingExpandedLiveActivity &&
            notchViewModel.notchModel.content?.id == NotchContentRegistry.DragAndDrop.trayActive.id
        )
    }
    
    var visibleStrokeColor: Color {
        notchViewModel.displayedContent?.strokeColor ?? notchViewModel.cachedStrokeColor
    }
    
    @ViewBuilder
    var notchSurface: some View {
        NotchBackgroundSurface(
            style: settingsViewModel.application.notchBackgroundStyle,
            topCornerRadius: notchViewModel.interactiveCornerRadius.top,
            bottomCornerRadius: notchViewModel.interactiveCornerRadius.bottom,
            strokeColor: shouldShowStroke ? visibleStrokeColor : .clear,
            strokeWidth: settingsViewModel.notchStrokeWidth
        )
    }
    
    var shouldShowStroke: Bool {
        settingsViewModel.isShowNotchStrokeEnabled &&
        notchViewModel.displayedContent != nil
    }
    
    @ViewBuilder
    var contentOverlay: some View {
        if let content = notchViewModel.displayedContent {
            renderedContentView(for: content)
                .resizeAwareBlur(
                    size: notchViewModel.interactiveNotchSize,
                    interactiveBlur: notchViewModel.contentResizeBlurRadius,
                    interactiveOpacity: notchViewModel.contentResizeOpacity
                )
                .id(notchViewModel.displayedPresentationID)
                .transition(
                    notchViewModel.contentTransition(
                        notchWidth: notchViewModel.presentedNotchSize.width,
                        notchHeight: notchViewModel.presentedNotchSize.height,
                        baseHeight: notchViewModel.notchModel.baseHeight,
                        isExpandedPresentation: notchViewModel.isDisplayingExpandedLiveActivity,
                        isCompactRemovalForExpansion: notchViewModel.isExpandingLiveActivityTransition
                    )
                )
        }
    }
    
    @MainActor
    @ViewBuilder
    func renderedContentView(for content: NotchContentProtocol) -> some View {
        if notchViewModel.isDisplayingExpandedLiveActivity {
            content.makeExpandedView()
        } else {
            content.makeView()
        }
    }
    
    @ViewBuilder
    var contextMenuItem: some View {
        Button {
            openWindow(id: WindowsScene.settings)
            SettingsWindowCoordinator.activate()
        } label: {
            Image(systemName: "gearshape")
            Text(verbatim: "Settings")
        }
        
        Divider()
        
        Button(action: { AppRelauncher.restartApp() }) {
            Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
            Text(verbatim: "Restart")
        }
        
        Button(action: { NSApp.terminate(nil) }) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
            Text(verbatim: "Quit")
        }
    }
}

private struct NotchEventHandlersView: View {
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
            .onReceive(powerViewModel.$event.compactMap { $0 }) { event in
                notchEventCoordinator.handlePowerEvent(event)
            }
            .onReceive(bluetoothViewModel.$event.compactMap { $0 }) { event in
                notchEventCoordinator.handleBluetoothEvent(event)
            }
            .onReceive(networkViewModel.$networkEvent.compactMap { $0 }) { event in
                notchEventCoordinator.handleNetworkEvent(event)
            }
            .onReceive(downloadViewModel.$event.compactMap { $0 }) { event in
                notchEventCoordinator.handleDownloadEvent(event)
            }
            .onReceive(focusViewModel.$focusEvent.compactMap { $0 }) { event in
                notchEventCoordinator.handleFocusEvent(event)
            }
            .onReceive(airDropViewModel.$event.compactMap { $0 }) { event in
                notchEventCoordinator.handleAirDropEvent(event)
            }
            .onReceive(settingsViewModel.notchSizeEvent) { event in
                notchEventCoordinator.handleNotchWidthEvent(event)
            }
            .onReceive(nowPlayingViewModel.$event.compactMap { $0 }) { event in
                notchEventCoordinator.handleNowPlayingEvent(event)
            }
            .onReceive(timerViewModel.$event.compactMap { $0 }) { event in
                notchEventCoordinator.handleTimerEvent(event)
            }
            .onReceive(screenRecordingViewModel.$event.compactMap { $0 }) { event in
                notchEventCoordinator.handleScreenRecordingEvent(event)
            }
            .onReceive(lockScreenManager.$event.compactMap { $0 }) { event in
                notchEventCoordinator.handleLockScreenEvent(event)
            }
    }
}

private struct ProgressRing: View {
    let progress: Double
    let color: Color
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 2)
            Circle()
                .trim(from: 0, to: min(progress / 100, 1))
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
            VStack(spacing: 0) {
                Text("\(Int(progress))")
                    .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Dashboard

enum DashboardTab: String, CaseIterable {
    case music    = "Music"
    case system   = "System"
    case calendar = "Calendar"

    var icon: String {
        switch self {
        case .music:    return "music.note"
        case .system:   return "cpu"
        case .calendar: return "calendar"
        }
    }
}

private struct DashboardPanelView: View {
    @ObservedObject var systemMonitorViewModel: SystemMonitorViewModel
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @Binding var selectedTab: DashboardTab

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Color.white.opacity(0.1).frame(height: 0.5)
            tabContent
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon).font(.system(size: 10))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.35))
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(selectedTab == tab ? Color.white.opacity(0.1) : .clear)
                    .animation(.easeInOut(duration: 0.15), value: selectedTab)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .music:
            musicView.transition(.opacity)
        case .system:
            systemView.transition(.opacity)
        case .calendar:
            CalendarTabView().transition(.opacity)
        }
    }

    // MARK: Music tab

    private var musicView: some View {
        Group {
            if let snapshot = nowPlayingViewModel.snapshot {
                MusicPlayerView(
                    snapshot: snapshot,
                    artwork: nowPlayingViewModel.artworkImage,
                    onPlayPause: { nowPlayingViewModel.togglePlayPause() },
                    onPrev:      { nowPlayingViewModel.previousTrack() },
                    onNext:      { nowPlayingViewModel.nextTrack() },
                    onShuffle:   { nowPlayingViewModel.toggleShuffle() },
                    onRepeat:    { nowPlayingViewModel.toggleRepeat() }
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
    }

    // MARK: System tab

    private var systemView: some View {
        VStack(spacing: 8) {
            StatBar(label: "CPU",
                    fraction: systemMonitorViewModel.cpuUsage / 100,
                    valueText: "\(Int(systemMonitorViewModel.cpuUsage))%",
                    color: usageColor(systemMonitorViewModel.cpuUsage, warn: 50, danger: 80))
            StatBar(label: "MEM",
                    fraction: systemMonitorViewModel.memoryUsage / 100,
                    valueText: "\(Int(systemMonitorViewModel.memoryUsage))%",
                    color: usageColor(systemMonitorViewModel.memoryUsage, warn: 70, danger: 85))
            StatBar(label: "NET\u{2191}",
                    fraction: min(systemMonitorViewModel.uploadSpeed / 20_000_000, 1),
                    valueText: systemMonitorViewModel.formattedSpeed(systemMonitorViewModel.uploadSpeed),
                    color: netSpeedColor(systemMonitorViewModel.uploadSpeed))
            StatBar(label: "NET\u{2193}",
                    fraction: min(systemMonitorViewModel.downloadSpeed / 20_000_000, 1),
                    valueText: systemMonitorViewModel.formattedSpeed(systemMonitorViewModel.downloadSpeed),
                    color: netSpeedColor(systemMonitorViewModel.downloadSpeed))
            StatBar(label: systemMonitorViewModel.isCharging ? "BAT\u{26A1}" : "BAT",
                    fraction: Double(systemMonitorViewModel.batteryLevel) / 100,
                    valueText: "\(systemMonitorViewModel.batteryLevel)%",
                    color: batteryColor(systemMonitorViewModel.batteryLevel,
                                        isCharging: systemMonitorViewModel.isCharging))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    private func usageColor(_ v: Double, warn: Double, danger: Double) -> Color {
        v >= danger ? .red : v >= warn ? .orange : .green.opacity(0.9)
    }

    private func batteryColor(_ level: Int, isCharging: Bool) -> Color {
        if isCharging { return .green }
        if level <= 20 { return .red }
        if level <= 40 { return .orange }
        return .green.opacity(0.9)
    }

    private func netSpeedColor(_ bps: Double) -> Color {
        switch bps {
        case ..<100_000:    return .white.opacity(0.5)
        case ..<1_000_000:  return .green
        case ..<5_000_000:  return .cyan
        case ..<20_000_000: return .yellow
        default:            return .orange
        }
    }
}

private struct StatBar: View {
    let label: String
    let fraction: Double
    let valueText: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 44, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(color)
                        .frame(width: max(4, geo.size.width * CGFloat(min(fraction, 1))))
                        .animation(.easeInOut(duration: 0.4), value: fraction)
                }
            }
            .frame(height: 4)

            Text(valueText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

// MARK: - MusicPlayerView

private struct MusicPlayerView: View {
    let snapshot: NowPlayingSnapshot
    let artwork: NSImage?
    let onPlayPause: () -> Void
    let onPrev: () -> Void
    let onNext: () -> Void
    let onShuffle: () -> Void
    let onRepeat: () -> Void

    @State private var scrubProgress: Double? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: snapshot.isPlaying ? 0.5 : 60)) { context in
            let elapsed = snapshot.elapsedTime(at: context.date)
            let progress = snapshot.duration > 0 ? elapsed / snapshot.duration : 0
            content(progress: scrubProgress ?? progress)
        }
    }

    private func content(progress: Double) -> some View {
        HStack(spacing: 12) {
            artworkView
            VStack(alignment: .leading, spacing: 6) {
                metadataRow
                progressBar(progress: progress)
                controlsRow
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var artworkView: some View {
        Group {
            if let img = artwork {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.07))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.25))
                    }
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var metadataRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.title.isEmpty ? "Unknown" : snapshot.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(snapshot.artist.isEmpty ? "\u{2014}" : snapshot.artist)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
    }

    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(Color.white.opacity(0.65))
                    .frame(width: max(4, geo.size.width * CGFloat(min(progress, 1))))
            }
        }
        .frame(height: 3)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    scrubProgress = Double(val.location.x / val.translation.width.magnitude.advanced(by: val.location.x))
                }
                .onEnded { val in scrubProgress = nil }
        )
    }

    private var controlsRow: some View {
        HStack(spacing: 18) {
            Button(action: onShuffle) {
                Image(systemName: "shuffle")
                    .font(.system(size: 11))
                    .foregroundStyle(snapshot.isShuffled ? .white : .white.opacity(0.3))
            }
            .buttonStyle(.plain)

            Button(action: onPrev) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button(action: onPlayPause) {
                Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20)
            }
            .buttonStyle(.plain)

            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button(action: onRepeat) {
                Image(systemName: snapshot.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 11))
                    .foregroundStyle(snapshot.repeatMode != .off ? .white : .white.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - CalendarTabView

private struct CalendarTabView: View {
    @StateObject private var store = CalendarStore()

    var body: some View {
        Group {
            switch store.authStatus {
            case .notDetermined:
                Button("Grant calendar access") { store.requestAccess() }
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .denied, .restricted:
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Calendar access denied")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                if store.events.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("No events today")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(store.events, id: \.eventIdentifier) { event in
                                EventRow(event: event)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .onAppear { store.loadIfNeeded() }
    }
}

private struct EventRow: View {
    let event: EKEvent

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(timeString)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
    }

    private var timeString: String {
        if event.isAllDay { return "All day" }
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.dateStyle = .none
        return "\(fmt.string(from: event.startDate)) \u{2013} \(fmt.string(from: event.endDate))"
    }
}

@MainActor
private final class CalendarStore: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private let ekStore = EKEventStore()

    func loadIfNeeded() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authStatus = status
        if status == .fullAccess { fetchToday() }
    }

    func requestAccess() {
        Task {
            _ = try? await ekStore.requestFullAccessToEvents()
            authStatus = EKEventStore.authorizationStatus(for: .event)
            if authStatus == .fullAccess { fetchToday() }
        }
    }

    private func fetchToday() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        let pred = ekStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = ekStore.events(matching: pred)
            .sorted { $0.startDate < $1.startDate }
    }
}
