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
    @State private var notchTapFired = false
    @State private var tabDisplayOrder: [DashboardTab] = DashboardTab.allCases
    @State private var draggingTab: DashboardTab? = nil
    @State private var dragTranslation: CGFloat = 0
    @State private var dragSourceIndex: Int = 0
    @State private var dragTargetIndex: Int = 0
    @State private var appSearchText = ""
    // Calibrated to match BoringNotch: window=640pt, each side = (640-156)/2 - sideWidth ≈ 152
    private let pillExpandExtra: CGFloat = 152

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
    // Apps tab expands height to ~3× the standard panel (173 × 3 ≈ 519)
    var dashboardPanelHeight: CGFloat { dashboardTab == .apps ? 519 : 173 }

    private var enabledDashboardTabs: [DashboardTab] {
        tabDisplayOrder.filter {
            !settingsViewModel.application.dashboardDisabledTabs.contains($0.rawValue)
        }
    }

    private func reorderTab(_ tab: DashboardTab, to targetEnabledIndex: Int) {
        let tabs = enabledDashboardTabs
        let clamped = max(0, min(tabs.count - 1, targetEnabledIndex))
        guard let fromIdx = tabs.firstIndex(of: tab), clamped != fromIdx else { return }
        let targetTab = tabs[clamped]
        guard let fullFrom = tabDisplayOrder.firstIndex(of: tab),
              let fullTo   = tabDisplayOrder.firstIndex(of: targetTab) else { return }
        var order = tabDisplayOrder
        order.remove(at: fullFrom)
        order.insert(tab, at: fullTo)
        tabDisplayOrder = order
    }

    // One unified black strip: [left content | notch bridge | right content]
    // The notch body renders on top — the bridge section is invisible (black on black).
    var pillStrip: some View {
        let notchBridgeWidth = max(0,
            notchViewModel.presentedNotchSize.width - 2 * notchViewModel.interactiveCornerRadius.top
        )
        let spring: Animation = dashboardOpen
            ? .spring(response: 0.22, dampingFraction: 0.8)
            : .spring(response: 0.38, dampingFraction: 0.7)

        let totalWidth = 2 * activeSideWidth + notchBridgeWidth

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left: speed arrows ↔ tab indicators (same notch-bar level)
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
                    .opacity(dashboardOpen ? 0 : 1)
                    .scaleEffect(dashboardOpen ? 0.72 : 1, anchor: .leading)
                    .allowsHitTesting(!dashboardOpen)
                    .animation(spring, value: dashboardOpen)
                    // Tab indicators — overlay so speed arrows still drive the layout width
                    .overlay(alignment: .leading) {
                        let iconSlot: CGFloat = 31
                        HStack(spacing: 3) {
                            ForEach(Array(enabledDashboardTabs.enumerated()), id: \.element) { (tabIdx, tab) in
                                let isDragging = draggingTab == tab
                                let sideOffset: CGFloat = {
                                    guard draggingTab != nil, !isDragging else { return 0 }
                                    let src = dragSourceIndex, tgt = dragTargetIndex
                                    if src < tgt, tabIdx > src, tabIdx <= tgt { return -iconSlot }
                                    if src > tgt, tabIdx >= tgt, tabIdx < src { return  iconSlot }
                                    return 0
                                }()
                                Button {
                                    if draggingTab == nil {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                            dashboardTab = tab
                                        }
                                    }
                                } label: {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(dashboardTab == tab ? .white : .white.opacity(0.5))
                                        .frame(width: 28, height: 28)
                                        .background(dashboardTab == tab ? Color.white.opacity(0.14) : .clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                        .contentShape(Rectangle())
                                        .animation(.easeInOut(duration: 0.15), value: dashboardTab)
                                }
                                .buttonStyle(.plain)
                                .offset(x: isDragging ? dragTranslation : sideOffset)
                                .scaleEffect(isDragging ? 1.18 : 1)
                                .opacity(isDragging ? 0.72 : 1)
                                .zIndex(isDragging ? 1 : 0)
                                .animation(.spring(response: 0.26, dampingFraction: 0.78), value: sideOffset)
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 5)
                                        .onChanged { val in
                                            if draggingTab == nil {
                                                dragSourceIndex = tabIdx
                                                dragTargetIndex = tabIdx
                                            }
                                            draggingTab = tab
                                            dragTranslation = val.translation.width
                                            let delta = Int(round(val.translation.width / iconSlot))
                                            let newTgt = max(0, min(enabledDashboardTabs.count - 1, dragSourceIndex + delta))
                                            if newTgt != dragTargetIndex { dragTargetIndex = newTgt }
                                        }
                                        .onEnded { val in
                                            let delta = Int(round(val.translation.width / iconSlot))
                                            let toIdx = max(0, min(enabledDashboardTabs.count - 1, dragSourceIndex + delta))
                                            if delta != 0 { reorderTab(tab, to: toIdx) }
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                                draggingTab = nil
                                                dragTranslation = 0
                                            }
                                        }
                                )
                            }
                        }
                        .fixedSize()
                        .offset(x: -(outerPad - 8))
                        .opacity(dashboardOpen ? 1 : 0)
                        .scaleEffect(dashboardOpen ? 1 : 0.72, anchor: .leading)
                        .allowsHitTesting(dashboardOpen)
                        .animation(spring, value: dashboardOpen)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: activeSideWidth, height: baseHeight)
                .contentShape(Rectangle())
                .onTapGesture { toggleDashboard() }

                // Bridge: hidden under the notch — notch body handles its own tap
                Color.clear.frame(width: notchBridgeWidth, height: baseHeight)

                // Right: CPU + MEM rings ↔ settings button (same notch-bar level)
                HStack(spacing: 0) {
                    Color.clear.frame(width: notchClearance)
                    Spacer(minLength: 0)
                    ZStack(alignment: .trailing) {
                        HStack(spacing: 8) {
                            ProgressRing(
                                progress: systemMonitorViewModel.cpuUsage,
                                color: pillColor(systemMonitorViewModel.cpuUsage, warn: 50, danger: 80),
                                label: "CPU"
                            )
                            .frame(width: ringSize, height: ringSize)
                            ProgressRing(
                                progress: systemMonitorViewModel.memoryUsage,
                                color: pillColor(systemMonitorViewModel.memoryUsage, warn: 70, danger: 85),
                                label: "MEM"
                            )
                            .frame(width: ringSize, height: ringSize)
                        }
                        .opacity(dashboardOpen ? 0 : 1)
                        .scaleEffect(dashboardOpen ? 0.72 : 1, anchor: .trailing)
                        .allowsHitTesting(!dashboardOpen)

                        Button {
                            openWindow(id: WindowsScene.settings)
                            SettingsWindowCoordinator.activate()
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.09))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .opacity(dashboardOpen && dashboardTab != .apps ? 1 : 0)
                        .scaleEffect(dashboardOpen && dashboardTab != .apps ? 1 : 0.72, anchor: .trailing)
                        .allowsHitTesting(dashboardOpen && dashboardTab != .apps)

                        // Search bar — visible when apps tab is active
                        HStack(spacing: 5) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.45))
                            TextField("Search apps", text: $appSearchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                            if !appSearchText.isEmpty {
                                Button { appSearchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .frame(maxWidth: 220)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(dashboardOpen && dashboardTab == .apps ? 1 : 0)
                        .scaleEffect(dashboardOpen && dashboardTab == .apps ? 1 : 0.72, anchor: .trailing)
                        .allowsHitTesting(dashboardOpen && dashboardTab == .apps)
                    }
                    .animation(spring, value: dashboardOpen)
                    .animation(spring, value: dashboardTab == .apps)
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
                    selectedTab: $dashboardTab,
                    appSearchText: $appSearchText,
                    enabledTabs: enabledDashboardTabs
                )
                .frame(height: dashboardPanelHeight)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: dashboardPanelHeight)
                .transition(.opacity)
                .onChange(of: settingsViewModel.application.dashboardDisabledTabs) {
                    let enabled = enabledDashboardTabs
                    if !enabled.isEmpty, !enabled.contains(dashboardTab) {
                        dashboardTab = enabled[0]
                    }
                }
                .onChange(of: dashboardTab) { _, newTab in
                    if newTab != .apps { appSearchText = "" }
                }
            }
        }
        .frame(width: totalWidth)
        .animation(.spring(response: 0.42, dampingFraction: 0.85), value: totalWidth)
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
        case ..<50_000:           return .cyan
        case ..<500_000:          return .mint
        case ..<5_000_000:        return .green
        case ..<20_000_000:       return .yellow
        default:                  return .orange
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
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !notchTapFired else { return }
                        notchTapFired = true
                        toggleDashboard()
                    }
                    .onEnded { _ in notchTapFired = false }
            )
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
    var valueText: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: min(progress / 100, 1))
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
            VStack(spacing: 1) {
                Text(valueText ?? "\(Int(progress))")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 6, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }
}

// MARK: - Dashboard

enum DashboardTab: String, CaseIterable {
    case music    = "Music"
    case system   = "System"
    case calendar = "Calendar"
    case apps     = "Apps"

    var icon: String {
        switch self {
        case .music:    return "music.note"
        case .system:   return "cpu"
        case .calendar: return "calendar"
        case .apps:     return "square.grid.2x2"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .music:    return "Music"
        case .system:   return "System Status"
        case .calendar: return "Calendar"
        case .apps:     return "App Launcher"
        }
    }

    var settingsDescription: LocalizedStringKey {
        switch self {
        case .music:    return "Music player with playback controls and progress bar."
        case .system:   return "CPU, memory, disk, network, and battery stats."
        case .calendar: return "Today's calendar events from your calendars."
        case .apps:     return "Quick launcher for pinned apps."
        }
    }

    var settingsColor: Color {
        switch self {
        case .music:    return .pink
        case .system:   return .blue
        case .calendar: return .orange
        case .apps:     return .purple
        }
    }
}

private struct DashboardPanelView: View {
    @ObservedObject var systemMonitorViewModel: SystemMonitorViewModel
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @Binding var selectedTab: DashboardTab
    @Binding var appSearchText: String
    var enabledTabs: [DashboardTab]

    private var selectedIndex: Int {
        enabledTabs.firstIndex(of: selectedTab) ?? 0
    }

    var body: some View {
        pageContent
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
            HStack(spacing: 0) {
                ForEach(enabledTabs, id: \.self) { tab in
                    tabPage(for: tab).frame(width: geo.size.width)
                }
            }
            .offset(x: -CGFloat(selectedIndex) * geo.size.width)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
        }
        .clipped()
    }

    @ViewBuilder
    private func tabPage(for tab: DashboardTab) -> some View {
        switch tab {
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
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                gaugeCard(
                    title: "CPU",
                    value: systemMonitorViewModel.cpuUsage,
                    valueText: "\(Int(systemMonitorViewModel.cpuUsage))%",
                    color: usageColor(systemMonitorViewModel.cpuUsage, warn: 50, danger: 80)
                )
                gaugeCard(
                    title: "MEM",
                    value: systemMonitorViewModel.memoryUsage,
                    valueText: "\(Int(systemMonitorViewModel.memoryUsage))%",
                    color: usageColor(systemMonitorViewModel.memoryUsage, warn: 70, danger: 85)
                )
                gaugeCard(
                    title: systemMonitorViewModel.isCharging ? "BAT\u{26A1}" : "BAT",
                    value: Double(systemMonitorViewModel.batteryLevel),
                    valueText: "\(systemMonitorViewModel.batteryLevel)%",
                    color: batteryColor(systemMonitorViewModel.batteryLevel,
                                        isCharging: systemMonitorViewModel.isCharging)
                )
                gaugeCard(
                    title: "DISK",
                    value: systemMonitorViewModel.diskUsage,
                    valueText: systemMonitorViewModel.diskUsedText,
                    color: usageColor(systemMonitorViewModel.diskUsage, warn: 80, danger: 90)
                )
            }
            networkCard
            infoStrip
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var infoStrip: some View {
        HStack(spacing: 7) {
            infoCell(
                icon: "clock",
                label: "Uptime",
                value: uptimeString
            )
            infoCell(
                icon: "square.stack.3d.up",
                label: "Apps",
                value: "\(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.count)"
            )
            infoCell(
                icon: "internaldrive",
                label: "Free",
                value: systemMonitorViewModel.diskTotalText
            )
        }
    }

    private func infoCell(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var uptimeString: String {
        let s = Int(ProcessInfo.processInfo.systemUptime)
        let d = s / 86400; let h = (s % 86400) / 3600; let m = (s % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func gaugeCard(title: String, value: Double, valueText: String, color: Color) -> some View {
        ProgressRing(progress: value, color: color, label: title, valueText: valueText)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var networkCard: some View {
        HStack(spacing: 0) {
            netSpeedCell(sfSymbol: "arrow.up", label: "Upload",
                         speed: systemMonitorViewModel.uploadSpeed)
            Color.white.opacity(0.1).frame(width: 0.5)
            netSpeedCell(sfSymbol: "arrow.down", label: "Download",
                         speed: systemMonitorViewModel.downloadSpeed)
        }
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func netSpeedCell(sfSymbol: String, label: String, speed: Double) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(netSpeedColor(speed))
                Text(systemMonitorViewModel.formattedSpeed(speed))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(netSpeedColor(speed))
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
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
        case ..<50_000:     return .cyan
        case ..<500_000:    return .mint
        case ..<2_000_000:  return .green
        case ..<10_000_000: return .yellow
        case ..<50_000_000: return .orange
        default:            return .red
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

// MARK: - AppLauncherView

private struct AppLauncherView: View {
    @Binding var searchText: String
    @StateObject private var store = AppLauncherStore()

    private var filteredApps: [URL] {
        guard !searchText.isEmpty else { return store.apps }
        let q = searchText.lowercased()
        return store.apps.filter {
            $0.deletingPathExtension().lastPathComponent.lowercased().contains(q)
        }
    }

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredApps.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("No apps found")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 76), spacing: 8)],
                        spacing: 14
                    ) {
                        ForEach(filteredApps, id: \.self) { url in
                            AppIconButton(url: url)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .onAppear { store.loadIfNeeded() }
    }
}

private struct AppIconButton: View {
    let url: URL
    @State private var isHovered = false

    var body: some View {
        Button {
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } label: {
            VStack(spacing: 5) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .scaleEffect(isHovered ? 1.18 : 1.0)
                    .shadow(color: .black.opacity(isHovered ? 0.35 : 0), radius: 8, y: 4)
                    .animation(.spring(response: 0.18, dampingFraction: 0.62), value: isHovered)

                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .frame(maxWidth: 72)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

@MainActor
private final class AppLauncherStore: ObservableObject {
    @Published private(set) var apps: [URL] = []
    @Published private(set) var isLoading = false

    private var loaded = false

    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        isLoading = true
        Task {
            let result = await Self.scanApps()
            apps = result
            isLoading = false
        }
    }

    private static func scanApps() async -> [URL] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let dirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            (home as NSString).appendingPathComponent("Applications")
        ]
        var seen = Set<String>()
        var result: [URL] = []
        for dir in dirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items.sorted() where item.hasSuffix(".app") {
                let path = (dir as NSString).appendingPathComponent(item)
                if seen.insert(path).inserted {
                    result.append(URL(fileURLWithPath: path))
                }
            }
        }
        return result.sorted {
            $0.deletingPathExtension().lastPathComponent.lowercased() <
            $1.deletingPathExtension().lastPathComponent.lowercased()
        }
    }
}

// MARK: - SwipeEventMonitor

/// Detects two-finger horizontal trackpad swipes via NSEvent monitoring.
/// Install as .background() on a view that is only in the hierarchy when swipe should be active.
/// The monitor is automatically removed when the view is dismantled (e.g. dashboardOpen = false).
private struct SwipeEventMonitor: NSViewRepresentable {
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        context.coordinator.start(left: onSwipeLeft, right: onSwipeRight)
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onSwipeLeft = onSwipeLeft
        context.coordinator.onSwipeRight = onSwipeRight
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var onSwipeLeft: (() -> Void)?
        var onSwipeRight: (() -> Void)?
        private var monitor: Any?
        private var accumX: CGFloat = 0
        private var didFire = false
        private var lastFiredAt: Date = .distantPast
        private let cooldown: TimeInterval = 0.45

        func start(left: @escaping () -> Void, right: @escaping () -> Void) {
            onSwipeLeft = left
            onSwipeRight = right
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func stop() {
            if let m = monitor { NSEvent.removeMonitor(m) }
            monitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            if event.phase == .began {
                accumX = 0
                // 冷却期内忽略新手势
                didFire = Date().timeIntervalSince(lastFiredAt) < cooldown
            }
            if event.phase == .ended || event.phase == .cancelled {
                accumX = 0
                return event
            }

            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            guard abs(dx) > abs(dy) * 1.4, abs(dx) > 1 else { return event }

            if didFire { return nil }

            accumX += dx
            if accumX < -55 {
                didFire = true
                accumX = 0
                lastFiredAt = Date()
                DispatchQueue.main.async { self.onSwipeLeft?() }
                return nil
            } else if accumX > 55 {
                didFire = true
                accumX = 0
                lastFiredAt = Date()
                DispatchQueue.main.async { self.onSwipeRight?() }
                return nil
            }
            return event
        }
    }
}
