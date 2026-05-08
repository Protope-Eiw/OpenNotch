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
    @StateObject private var pomodoroViewModel = PomodoroViewModel()
    @AppStorage(AppStorageKeys.NotchBar.leftWidgets)  private var leftWidgetsRaw  = NotchBarWidget.networkSpeed.rawValue
    @AppStorage(AppStorageKeys.NotchBar.rightWidgets) private var rightWidgetsRaw = "cpu,memory"
    @AppStorage(AppStorageKeys.NotchBar.hideWidgets)  private var hideWidgets     = false
    @AppStorage(AppStorageKeys.General.dashboardLastTab)    private var dashboardLastTab    = DashboardTab.system.rawValue
    @AppStorage(AppStorageKeys.General.dashboardDefaultTab) private var dashboardDefaultTab = "last"
    // Separate show/hide state so widgets only reappear after the notch finishes collapsing
    @State private var showSideWidgets = true
    @State private var sideWidgetTask: Task<Void, Never>? = nil
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
        .onChange(of: dashboardOpen) { _, isOpen in
            if isOpen {
                applyDashboardTabPolicy()
                // Dashboard opening — show side strip immediately (tab indicators live there)
                sideWidgetTask?.cancel()
                sideWidgetTask = nil
                showSideWidgets = true
            } else {
                dashboardLastTab = dashboardTab.rawValue
            }
        }
        .onChange(of: notchExpandedDownward) { _, expanding in
            sideWidgetTask?.cancel()
            sideWidgetTask = nil
            if expanding {
                // Notch expanding downward — hide side widgets fast
                withAnimation(.easeIn(duration: 0.12).delay(0.04)) {
                    showSideWidgets = false
                }
            } else {
                // Notch just started collapsing — wait for the spring to fully settle,
                // then show side widgets.
                let delay = sideWidgetRevealDelay
                sideWidgetTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                        showSideWidgets = true
                    }
                }
            }
        }
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
    // Collapses to 0 when side widgets are hidden (notch expanding downward) or settings toggle is off.
    var notchExpandedSideWidth: CGFloat { (!showSideWidgets || (hideWidgets && !dashboardOpen)) ? 0 : activeSideWidth }
    // Apps tab expands height to ~3× the standard panel (173 × 3 ≈ 519)
    var dashboardPanelHeight: CGFloat { dashboardTab == .apps ? 519 : 173 }

    var isMusicTabPlaying: Bool {
        dashboardOpen && dashboardTab == .music && nowPlayingViewModel.snapshot?.isPlaying == true
    }

    var artworkTintColor: Color {
        Color(nsColor: nowPlayingViewModel.artworkPalette.equalizerBaseColor)
    }

    // True when the notch body is taller than the base pill height (content pushing down)
    // and the dashboard is not open (dashboard has its own animation path).
    private var notchExpandedDownward: Bool {
        !dashboardOpen && notchViewModel.presentedNotchSize.height > baseHeight
    }

    // How long to wait after notchExpandedDownward flips to false before showing side widgets.
    // contentHide spring with dampingFraction=0.7 settles to <1% at ~1.05 * response;
    // add 0.15s buffer so the notch looks fully collapsed before widgets appear.
    private var sideWidgetRevealDelay: TimeInterval {
        let response: Double
        switch settingsViewModel.application.notchAnimationPreset {
        case .snappy:   response = 0.41
        case .fast:     response = 0.44
        case .balanced: response = 0.47
        case .slow:     response = 0.50
        case .relaxed:  response = 0.53
        }
        return response * 1.05 + 0.15
    }

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

        let totalWidth = 2 * notchExpandedSideWidth + notchBridgeWidth

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left: speed arrows ↔ tab indicators (same notch-bar level)
                HStack(spacing: 0) {
                    Color.clear.frame(width: outerPad)
                    pillLeftWidgetView
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
                .opacity(showSideWidgets ? 1 : 0)
                .scaleEffect(showSideWidgets ? 1 : 0.90, anchor: .leading)
                .blur(radius: showSideWidgets ? 0 : 2)
                .frame(width: notchExpandedSideWidth, height: baseHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard settingsViewModel.application.dashboardOpenMode != .hover else { return }
                    toggleDashboard()
                }

                // Bridge: hidden under the notch — notch body handles its own tap
                Color.clear.frame(width: notchBridgeWidth, height: baseHeight)

                // Right: CPU + MEM rings ↔ settings button (same notch-bar level)
                HStack(spacing: 0) {
                    Color.clear.frame(width: notchClearance)
                    Spacer(minLength: 0)
                    ZStack(alignment: .trailing) {
                        pillRightWidgetView
                        .opacity(dashboardOpen ? 0 : 1)
                        .scaleEffect(dashboardOpen ? 0.72 : 1, anchor: .trailing)
                        .allowsHitTesting(!dashboardOpen)

                        Button {
                            openWindow(id: WindowsScene.settings)
                            SettingsWindowCoordinator.activate()
                            if dashboardOpen && settingsViewModel.application.dashboardOpenMode != .hover {
                                toggleDashboard()
                            }
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
                    .opacity(showSideWidgets ? 1 : 0)
                    .scaleEffect(showSideWidgets ? 1 : 0.90, anchor: .trailing)
                    .blur(radius: showSideWidgets ? 0 : 2)
                    Color.clear.frame(width: outerPad)
                }
                .frame(width: notchExpandedSideWidth, height: baseHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard settingsViewModel.application.dashboardOpenMode != .hover else { return }
                    toggleDashboard()
                }
            }

            if dashboardOpen {
                DashboardPanelView(
                    systemMonitorViewModel: systemMonitorViewModel,
                    nowPlayingViewModel: nowPlayingViewModel,
                    pomodoroViewModel: pomodoroViewModel,
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
                .background {
                    if settingsViewModel.application.dashboardOpenMode != .hover {
                        ClickOutsideMonitor {
                            toggleDashboard()
                        }
                    }
                }
            }
        }
        .frame(width: totalWidth)
        .animation(.spring(response: 0.42, dampingFraction: 0.85), value: dashboardOpen)
        .background(Color.black)
        .overlay(
            artworkTintColor
                .opacity(isMusicTabPlaying ? 0.18 : 0)
                .animation(.easeInOut(duration: 0.6), value: isMusicTabPlaying)
                .allowsHitTesting(false)
        )
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
            guard settingsViewModel.application.dashboardOpenMode == .hover else { return }
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
        guard !notchExpandedDownward else { return }

        dashboardHoverTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            guard !notchExpandedDownward else { return }
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
    private var pillLeftWidgetView: some View {
        let widgets = leftWidgetsRaw.split(separator: ",").compactMap { NotchBarWidget(rawValue: String($0)) }
        if pomodoroViewModel.state != .idle {
            HStack(spacing: 4) {
                Image(systemName: pomodoroViewModel.phase == .work ? "flame.fill" : "cup.and.heat.waves.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(pomodoroViewModel.phase == .work ? .orange : .mint)
                Text(pomodoroViewModel.timeString)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(pomodoroViewModel.phase == .work ? Color.orange : Color.mint)
            }
        } else if widgets.isEmpty {
            Color.clear.frame(width: 65, height: 1)
        } else {
            HStack(spacing: 6) {
                ForEach(Array(widgets.prefix(2)), id: \.self) { pillRingView(for: $0) }
            }
        }
    }

    @ViewBuilder
    private var pillRightWidgetView: some View {
        let widgets = rightWidgetsRaw.split(separator: ",").compactMap { NotchBarWidget(rawValue: String($0)) }
        if widgets.isEmpty {
            Color.clear.frame(width: CGFloat(ringSize * 2 + 8), height: 1)
        } else {
            HStack(spacing: 8) {
                ForEach(Array(widgets.prefix(2)), id: \.self) { pillRingView(for: $0) }
            }
        }
    }

    @ViewBuilder
    private func pillRingView(for widget: NotchBarWidget) -> some View {
        switch widget {
        case .networkSpeed:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.blue)
                    Text(systemMonitorViewModel.formattedSpeed(systemMonitorViewModel.uploadSpeed))
                        .foregroundStyle(.blue)
                }
                HStack(spacing: 3) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.green)
                    Text(systemMonitorViewModel.formattedSpeed(systemMonitorViewModel.downloadSpeed))
                        .foregroundStyle(.green)
                }
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
        case .cpu:
            ProgressRing(progress: systemMonitorViewModel.cpuUsage,
                         color: pillColor(systemMonitorViewModel.cpuUsage, warn: 50, danger: 80),
                         label: "CPU")
                .frame(width: ringSize, height: ringSize)
        case .memory:
            ProgressRing(progress: systemMonitorViewModel.memoryUsage,
                         color: pillColor(systemMonitorViewModel.memoryUsage, warn: 70, danger: 85),
                         label: "MEM")
                .frame(width: ringSize, height: ringSize)
        case .disk:
            ProgressRing(progress: systemMonitorViewModel.diskUsage,
                         color: pillColor(systemMonitorViewModel.diskUsage, warn: 80, danger: 90),
                         label: "DSK")
                .frame(width: ringSize, height: ringSize)
        }
    }

    private func applyDashboardTabPolicy() {
        let available = enabledDashboardTabs
        guard !available.isEmpty else { return }

        if dashboardDefaultTab != "last",
           let preferred = DashboardTab(rawValue: dashboardDefaultTab),
           available.contains(preferred) {
            dashboardTab = preferred
        } else {
            let savedTab = DashboardTab(rawValue: dashboardLastTab) ?? available[0]
            dashboardTab = available.contains(savedTab) ? savedTab : available[0]
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
                        guard settingsViewModel.application.dashboardOpenMode != .hover else { return }
                        guard !notchExpandedDownward else { return }
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
    var showInternalText: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: min(progress / 100, 1))
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
            if showInternalText {
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
}

// MARK: - Dashboard

enum DashboardTab: String, CaseIterable {
    case overview = "overview"
    case music    = "Music"
    case system   = "System"
    case calendar = "Calendar"
    case apps     = "Apps"

    var icon: String {
        switch self {
        case .overview: return "house.fill"
        case .music:    return "music.note"
        case .system:   return "cpu"
        case .calendar: return "calendar"
        case .apps:     return "square.grid.2x2"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .overview: return "Overview"
        case .music:    return "Music"
        case .system:   return "System Status"
        case .calendar: return "Calendar"
        case .apps:     return "App Launcher"
        }
    }

    var settingsDescription: LocalizedStringKey {
        switch self {
        case .overview: return "Quick overview with pinned apps, time, and system info."
        case .music:    return "Music player with playback controls and progress bar."
        case .system:   return "CPU, memory, disk, network, and battery stats."
        case .calendar: return "Today's calendar events from your calendars."
        case .apps:     return "Quick launcher for pinned apps."
        }
    }

    var settingsColor: Color {
        switch self {
        case .overview: return .teal
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
            // 左+中：3列2行，环形卡片与速度卡片等宽
            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    gaugeCard(title: "CPU",
                              value: systemMonitorViewModel.cpuUsage,
                              valueText: "\(Int(systemMonitorViewModel.cpuUsage))%",
                              color: usageColor(systemMonitorViewModel.cpuUsage, warn: 50, danger: 80))
                    gaugeCard(title: "MEM",
                              value: systemMonitorViewModel.memoryUsage,
                              valueText: "\(Int(systemMonitorViewModel.memoryUsage))%",
                              color: usageColor(systemMonitorViewModel.memoryUsage, warn: 70, danger: 85))
                    speedCard(sfSymbol: "arrow.up",
                              speed: systemMonitorViewModel.uploadSpeed,
                              label: "Upload")
                }
                HStack(spacing: 7) {
                    gaugeCard(title: "DISK",
                              value: systemMonitorViewModel.diskUsage,
                              valueText: "\(Int(systemMonitorViewModel.diskUsage))%",
                              color: usageColor(systemMonitorViewModel.diskUsage, warn: 80, danger: 90))
                    gaugeCard(title: systemMonitorViewModel.isCharging ? "BAT⚡" : "BAT",
                              value: Double(systemMonitorViewModel.batteryLevel),
                              valueText: "\(systemMonitorViewModel.batteryLevel)%",
                              color: batteryColor(systemMonitorViewModel.batteryLevel,
                                                  isCharging: systemMonitorViewModel.isCharging))
                    speedCard(sfSymbol: "arrow.down",
                              speed: systemMonitorViewModel.downloadSpeed,
                              label: "Download")
                }
            }
            .frame(maxHeight: .infinity)

            // 右：机器信息，字体较大，左上对齐
            VStack(alignment: .leading, spacing: 8) {
                Text(macInfo?.modelName ?? "Mac")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                macInfoRow("cpu",        macInfo?.chipName     ?? "–")
                macInfoRow("memorychip", macInfo?.ramText      ?? "–")
                macInfoRow("barcode",    macInfo?.serialNumber ?? "–")
                macInfoRow("apple.logo", macInfo?.macOSVersion ?? "–")
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
                .foregroundStyle(netSpeedColor(speed))
            Text(systemMonitorViewModel.formattedSpeed(speed))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(netSpeedColor(speed))
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

// MARK: - OverviewView

private struct OverviewView: View {
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

    // 每个开启的模块横向等分，内容居中
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

    // MARK: – 应用快速启动列

    private var appsColumn: some View {
        ZStack(alignment: .bottomLeading) {
            // 主内容
            Group {
                if pinnedAppsStore.apps.isEmpty {
                    VStack(spacing: 5) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.12))
                        Text("点击 + 添加应用")
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
                                    Label("从快速启动移除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 左下角 + 按钮
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

    // MARK: – 时间 / 日期 / 天气列

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
                             ? String(format: "%.0f°", temp)
                             : String(format: "%@ %.0f°", weatherService.conditionText, temp))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Color.orange.opacity(0.8))
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "location.slash").font(.system(size: 9))
                        Text("获取天气中…").font(.system(size: 9))
                    }
                    .foregroundStyle(.white.opacity(0.2))
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – 系统信息列

    private var systemInfoColumn: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                statBlock("\(Int(systemMonitorViewModel.cpuUsage))%",  "CPU",
                          usageColor(systemMonitorViewModel.cpuUsage,  warn: 50, danger: 80))
                statBlock("\(Int(systemMonitorViewModel.memoryUsage))%", "RAM",
                          usageColor(systemMonitorViewModel.memoryUsage, warn: 70, danger: 85))
                statBlock("\(Int(systemMonitorViewModel.diskUsage))%",  "DISK",
                          usageColor(systemMonitorViewModel.diskUsage,  warn: 80, danger: 90))
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

    private func usageColor(_ v: Double, warn: Double, danger: Double) -> Color {
        v >= danger ? .red : v >= warn ? .orange : .green.opacity(0.9)
    }

    // MARK: – 番茄计时器列

    private var pomodoroColumn: some View {
        let isIdle      = pomodoroViewModel.state == .idle
        let accentColor: Color = pomodoroViewModel.phase == .work ? .orange : .mint
        let total       = max(1, pomodoroViewModel.phaseTotalSeconds)
        let progress    = isIdle ? 1.0 : min(1.0, Double(pomodoroViewModel.timeRemaining) / Double(total))

        return ZStack {
            // 深色圆形背景
            Circle()
                .fill(Color(red: 0.14, green: 0.10, blue: 0.08))

            // 轨道环
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 3)
                .padding(2)

            // 进度环
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accentColor.opacity(isIdle ? 0.4 : 0.9),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .padding(2)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: pomodoroViewModel.timeRemaining)

            // 内容
            VStack(spacing: 6) {
                Text(pomodoroViewModel.timeString)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Text(isIdle ? "\(workMinutes)m"
                     : pomodoroViewModel.phase == .work ? "专注中" : "休息中")
                    .font(.system(size: 9))
                    .foregroundStyle(isIdle ? .white.opacity(0.3) : accentColor.opacity(0.8))

                HStack(spacing: 10) {
                    // 播放/暂停
                    Button { pomodoroViewModel.toggleRunning() } label: {
                        Image(systemName: pomodoroViewModel.state == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    // +/- 1 分钟
                    VStack(spacing: 0) {
                        Button {
                            if isIdle {
                                if workMinutes < 120 { workMinutes += 1; pomodoroViewModel.updateWorkMinutes(workMinutes) }
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
                                if workMinutes > 1 { workMinutes -= 1; pomodoroViewModel.updateWorkMinutes(workMinutes) }
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

                    // 重置
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

private struct OverviewAppPickerView: View {
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
            // 搜索栏
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("搜索应用", text: $searchText)
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
                    Text(searchText.isEmpty ? "所有应用都已添加" : "未找到匹配应用")
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
                Text("已固定 \(store.apps.count) / 12 个应用")
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

// MARK: - PomodoroInlineView

private struct PomodoroInlineView: View {
    enum PomodoroState { case idle, work, rest }

    @AppStorage(AppStorageKeys.Overview.pomodoroDuration) private var workMinutes = 25
    @State private var state: PomodoroState = .idle
    @State private var remaining: Int = 0
    @State private var timerTask: Task<Void, Never>? = nil

    private var displayTime: String {
        let m = remaining / 60, s = remaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: state == .idle ? "timer" : state == .work ? "flame.fill" : "cup.and.heat.waves.fill")
                .font(.system(size: 10))
                .foregroundStyle(state == .work ? .orange : state == .rest ? .mint : .white.opacity(0.4))
            if state == .idle {
                Text("专注 \(workMinutes) 分钟")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button { start() } label: {
                    Text("开始")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            } else {
                Text(displayTime)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(state == .work ? .orange : .mint)
                Text(state == .work ? "专注中" : "休息中")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Button { stop() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func start() {
        remaining = workMinutes * 60
        state = .work
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled, remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled { remaining -= 1 }
            }
            if !Task.isCancelled { state = .idle }
        }
    }

    private func stop() {
        timerTask?.cancel()
        timerTask = nil
        state = .idle
    }
}

// MARK: - StatBar

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
    let onSeek: (TimeInterval) -> Void
    let onSkipBack: () -> Void
    let onSkipForward: () -> Void

    @AppStorage(AppStorageKeys.Music.showSkipButtons) private var showSkipButtons = true
    @AppStorage(AppStorageKeys.Music.showVisualizer)  private var showVisualizer  = true

    @State private var scrubProgress: Double? = nil
    @State private var isDragging = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: snapshot.isPlaying ? 0.5 : 60)) { context in
            let elapsed = snapshot.elapsedTime(at: context.date)
            let progress = snapshot.duration > 0 ? elapsed / snapshot.duration : 0
            content(elapsed: elapsed, progress: scrubProgress ?? progress)
        }
    }

    private func content(elapsed: TimeInterval, progress: Double) -> some View {
        HStack(spacing: 14) {
            artworkView

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.title.isEmpty ? "Unknown" : snapshot.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(snapshot.artist.isEmpty ? "–" : snapshot.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                        if showVisualizer {
                            AudioSpectrumView(isPlaying: snapshot.isPlaying)
                                .frame(width: 16, height: 10)
                                .opacity(snapshot.isPlaying ? 1 : 0.3)
                                .animation(.easeInOut(duration: 0.3), value: snapshot.isPlaying)
                        }
                    }
                }

                Spacer(minLength: 6)

                VStack(spacing: 5) {
                    progressBar(progress: progress)
                    HStack {
                        Text(timeString(elapsed))
                        Spacer()
                        Text(timeString(snapshot.duration))
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                }

                Spacer(minLength: 8)

                HStack(spacing: showSkipButtons ? 14 : 32) {
                    if showSkipButtons {
                        Button(action: onSkipBack) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onPrev) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: onPlayPause) {
                        Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22)
                    }
                    .buttonStyle(.plain)

                    Button(action: onNext) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    if showSkipButtons {
                        Button(action: onSkipForward) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 封面：播放时发光光晕 + 全尺寸；暂停时缩小 + 暗色蒙层
    private var artworkView: some View {
        ZStack {
            // 光晕层：封面旋转模糊，播放时可见
            if let img = artwork {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxHeight: .infinity)
                    .scaleEffect(x: 1.4, y: 1.5)
                    .rotationEffect(.degrees(92))
                    .blur(radius: 22)
                    .opacity(snapshot.isPlaying ? 0.55 : 0)
                    .animation(.easeInOut(duration: 0.45), value: snapshot.isPlaying)
            }

            // 主封面
            Group {
                if let img = artwork {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.07)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(snapshot.isPlaying ? 1.0 : 0.87)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: snapshot.isPlaying)

            // 暂停时的暗色蒙层
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(snapshot.isPlaying ? 0 : 0.5))
                .aspectRatio(1, contentMode: .fit)
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: snapshot.isPlaying)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxHeight: .infinity)
    }

    // 进度条：拖拽时变高，松手触发 seek
    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule().fill(Color.white.opacity(isDragging ? 1.0 : 0.8))
                    .frame(width: max(4, geo.size.width * CGFloat(min(progress, 1))))
            }
            .frame(height: isDragging ? 7 : 4)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
            .contentShape(Rectangle().size(CGSize(width: geo.size.width, height: 20)))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        withAnimation { isDragging = true }
                        scrubProgress = max(0, min(1, Double(val.location.x / geo.size.width)))
                    }
                    .onEnded { val in
                        let p = max(0, min(1, Double(val.location.x / geo.size.width)))
                        onSeek(p * snapshot.duration)
                        scrubProgress = nil
                        withAnimation { isDragging = false }
                    }
            )
        }
        .frame(height: 10)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let t = max(0, t)
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - CalendarTabView

private struct CalendarTabView: View {
    @StateObject private var store = CalendarStore()
    @State private var selectedDate = Date()
    @State private var displayedMonth: Date = {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()
    }()

    var body: some View {
        switch store.authStatus {
        case .notDetermined:
            calendarPermissionView(
                icon: "calendar",
                message: "需要日历权限",
                buttonLabel: "授权访问",
                action: { store.requestAccess() }
            )
        case .denied, .restricted:
            calendarPermissionView(
                icon: "calendar.badge.exclamationmark",
                message: "日历访问被拒绝",
                buttonLabel: "打开系统设置",
                action: { store.openPrivacySettings() }
            )
        default:
            HStack(spacing: 0) {
                MiniCalendarView(selectedDate: $selectedDate, displayedMonth: $displayedMonth)
                    .frame(width: 162)
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)
                    .padding(.vertical, 10)
                CalendarEventPane(
                    date: selectedDate,
                    events: store.events,
                    version: store.version
                )
            }
            .onAppear { store.load(for: selectedDate) }
            .onChange(of: selectedDate) { _, d in store.load(for: d) }
        }
    }

    private func calendarPermissionView(
        icon: String, message: String, buttonLabel: String, action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.2))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
            Button(buttonLabel, action: action)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mini Calendar

private struct MiniCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date

    private let cal = Calendar.current

    // Weekday header symbols, Monday-first, locale-aware
    private var weekdaySymbols: [String] {
        var s = cal.veryShortWeekdaySymbols   // Sunday-first
        s.append(s.removeFirst())             // rotate → Monday-first
        return s
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Month navigation ──
            HStack(spacing: 0) {
                Button { navigate(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.45))

                Spacer()

                Text(monthYearString)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .onTapGesture { jumpToToday() }

                Spacer()

                Button { navigate(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .padding(.bottom, 3)

            // ── Weekday labels ──
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.28))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)

            // ── Date grid ──
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7),
                spacing: 1
            ) {
                ForEach(gridCells, id: \.index) { cell in
                    if let date = cell.date {
                        MiniDateCell(
                            day: cal.component(.day, from: date),
                            isToday: cal.isDateInToday(date),
                            isSelected: cal.isDate(date, inSameDayAs: selectedDate)
                        ) {
                            selectedDate = date
                        }
                    } else {
                        Color.clear.frame(height: 19)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }

    private var monthYearString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: displayedMonth)
    }

    private func navigate(_ delta: Int) {
        guard let next = cal.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = cal.date(from: cal.dateComponents([.year, .month], from: next)) ?? next
    }

    private func jumpToToday() {
        let today = Date()
        selectedDate = today
        displayedMonth = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
    }

    private struct Cell { let index: Int; let date: Date? }

    private var gridCells: [Cell] {
        let start = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))!
        let daysInMonth = cal.range(of: .day, in: .month, for: start)!.count
        let firstWeekday = cal.component(.weekday, from: start) // Sun=1
        let leading = (firstWeekday + 5) % 7                   // Mon=0 … Sun=6

        var cells: [Cell] = []
        var idx = 0
        for _ in 0..<leading          { cells.append(Cell(index: idx, date: nil)); idx += 1 }
        for d in 0..<daysInMonth      { cells.append(Cell(index: idx, date: cal.date(byAdding: .day, value: d, to: start))); idx += 1 }
        let rem = cells.count % 7
        if rem != 0 { for _ in 0..<(7 - rem) { cells.append(Cell(index: idx, date: nil)); idx += 1 } }
        return cells
    }
}

private struct MiniDateCell: View {
    let day: Int
    let isToday: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(day)")
                .font(.system(size: 10.5, weight: isToday ? .semibold : .regular))
                .foregroundStyle(isToday || isSelected ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 19)
                .background(
                    isToday     ? Color.accentColor :
                    isSelected  ? Color.white.opacity(0.18) : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar Event Pane

private struct CalendarEventPane: View {
    let date: Date
    let events: [EKEvent]
    let version: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date label
            HStack {
                Text(dateLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.leading, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 5)
                Spacer()
            }

            Divider().opacity(0.08)

            if events.isEmpty {
                VStack(spacing: 5) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.15))
                    Text(Calendar.current.isDateInToday(date) ? "今天没有日程" : "没有日程")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(events, id: \.eventIdentifier) { event in
                                CalendarEventRow(event: event).id(event.eventIdentifier)
                                if event.eventIdentifier != events.last?.eventIdentifier {
                                    Divider().opacity(0.08).padding(.leading, 11)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .onAppear { scrollToUpcoming(proxy) }
                    .onChange(of: version) { _, _ in scrollToUpcoming(proxy) }
                }
            }
        }
    }

    private var dateLabel: String {
        let c = Calendar.current
        if c.isDateInToday(date)     { return "今天" }
        if c.isDateInYesterday(date) { return "昨天" }
        if c.isDateInTomorrow(date)  { return "明天" }
        let f = DateFormatter()
        f.dateFormat = c.component(.year, from: date) == c.component(.year, from: Date())
            ? "M月d日" : "yyyy年M月d日"
        return f.string(from: date)
    }

    private func scrollToUpcoming(_ proxy: ScrollViewProxy) {
        let now = Date()
        let target = events.first(where: { !$0.isAllDay && $0.endDate > now })
            ?? events.first(where: { $0.isAllDay })
            ?? events.last
        if let id = target?.eventIdentifier {
            withTransaction(Transaction(animation: nil)) { proxy.scrollTo(id, anchor: .top) }
        }
    }
}

// MARK: - Calendar Event Row

private struct CalendarEventRow: View {
    let event: EKEvent

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 3)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let loc = event.location, !loc.isEmpty {
                    Text(loc)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.38))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                if event.isAllDay {
                    Text("全天")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    Text(fmt(event.startDate))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                    Text(fmt(event.endDate))
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(.vertical, 5)
        .opacity(isPast ? 0.45 : 1)
    }

    private var isPast: Bool {
        !event.isAllDay
            && event.endDate < Date()
            && Calendar.current.isDateInToday(event.startDate)
    }

    private func fmt(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}

// MARK: - CalendarStore

@MainActor
private final class CalendarStore: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var version: Int = 0
    @Published var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private let ekStore = EKEventStore.app
    private var activeObserver: NSObjectProtocol?
    private var lastLoadedDate: Date?

    init() {
        // Refresh when user returns to the app (e.g. after granting access in System Settings)
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refreshStatus() }
        }
    }

    func load(for date: Date) {
        lastLoadedDate = date
        let status = EKEventStore.authorizationStatus(for: .event)
        authStatus = status
        guard isAuthorized(status) else { return }
        fetch(for: date)
    }

    func requestAccess() {
        Task {
            do {
                let granted = try await ekStore.requestFullAccessToEvents()
                // Trust the return value directly — don't re-read status yet,
                // TCC database can lag behind the dialog completion.
                if granted {
                    authStatus = .fullAccess
                    fetch(for: lastLoadedDate ?? Date())
                } else {
                    authStatus = .denied
                }
            } catch {
                // Hardened Runtime blocked the call or another error — open System Settings
                openPrivacySettings()
            }
        }
    }

    func openPrivacySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
        )
    }

    private func refreshStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authStatus = status
        if isAuthorized(status), let date = lastLoadedDate {
            fetch(for: date)
        }
    }

    private func isAuthorized(_ status: EKAuthorizationStatus) -> Bool {
        status == .fullAccess
    }

    private func fetch(for date: Date) {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start) ?? start
        let pred  = ekStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        events  = ekStore.events(matching: pred).sorted { $0.startDate < $1.startDate }
        version += 1
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
final class AppLauncherStore: ObservableObject {
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

// MARK: - ClickOutsideMonitor

/// Detects left-clicks outside the notch window and fires a dismiss callback.
/// Install as .background() on a view that is only in the hierarchy when dismiss-on-outside-click should be active.
/// Automatically removed when the view is dismantled.
private struct ClickOutsideMonitor: NSViewRepresentable {
    let onClickOutside: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        context.coordinator.start(onClickOutside: onClickOutside)
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onClickOutside = onClickOutside
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var onClickOutside: (() -> Void)?
        private var monitor: Any?

        func start(onClickOutside: @escaping () -> Void) {
            self.onClickOutside = onClickOutside
            monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                DispatchQueue.main.async { self?.onClickOutside?() }
            }
        }

        func stop() {
            if let m = monitor { NSEvent.removeMonitor(m) }
            monitor = nil
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

// MARK: - PomodoroViewModel

@MainActor
final class PomodoroViewModel: ObservableObject {
    enum PomodoroState { case idle, running, paused }
    enum PomodoroPhase { case work, shortBreak }

    @Published private(set) var state: PomodoroState = .idle
    @Published private(set) var phase: PomodoroPhase = .work
    @Published private(set) var timeRemaining: Int = 25 * 60

    private var countdownTask: Task<Void, Never>?
    private var _workMinutes: Int = 25

    var timeString: String { String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60) }
    var phaseTotalSeconds: Int { phase == .work ? _workMinutes * 60 : 5 * 60 }

    init() {
        let stored = UserDefaults.standard.integer(forKey: AppStorageKeys.Overview.pomodoroDuration)
        _workMinutes = stored > 0 ? stored : 25
        timeRemaining = _workMinutes * 60
    }

    func updateWorkMinutes(_ minutes: Int) {
        _workMinutes = minutes
        if state == .idle { timeRemaining = _workMinutes * 60 }
    }

    func toggleRunning() {
        switch state {
        case .idle:
            timeRemaining = _workMinutes * 60
            state = .running
            startCountdown()
        case .running:
            state = .paused
            countdownTask?.cancel()
        case .paused:
            state = .running
            startCountdown()
        }
    }

    func adjustTime(minutes: Int) {
        timeRemaining = max(0, timeRemaining + minutes * 60)
    }

    func reset() {
        countdownTask?.cancel()
        countdownTask = nil
        state = .idle
        phase = .work
        timeRemaining = _workMinutes * 60
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            while !Task.isCancelled, timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                timeRemaining -= 1
            }
            guard !Task.isCancelled else { return }
            if phase == .work {
                phase = .shortBreak
                timeRemaining = 5 * 60
                startCountdown()
            } else {
                phase = .work
                state = .idle
                timeRemaining = _workMinutes * 60
            }
        }
    }
}
