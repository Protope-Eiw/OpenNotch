import SwiftUI
import Combine
internal import AppKit


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
    @AppStorage(AppStorageKeys.General.dashboardLastTab)          private var dashboardLastTab          = DashboardTab.system.rawValue
    @AppStorage(AppStorageKeys.General.dashboardTransitionStyle)  private var dashboardTransitionStyle  = DashboardTransitionStyle.slide.rawValue
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
                    Task { @MainActor in
                        notchViewModel.updateDimensions()
                    }
                }
                .onChange(of: settingsViewModel.notchHeight) {
                    Task { @MainActor in
                        notchViewModel.updateDimensions()
                    }
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
    var ringSize:       CGFloat { max(0, baseHeight - 6) }
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
        let notchWidth = dashboardOpen
            ? notchViewModel.notchModel.baseWidth
            : notchViewModel.presentedNotchSize.width
        let notchBridgeWidth = max(0,
            notchWidth - 2 * notchViewModel.interactiveCornerRadius.top
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
                    PillLeftWidgetView(
                        systemMonitorViewModel: systemMonitorViewModel,
                        pomodoroViewModel: pomodoroViewModel,
                        widgetsRaw: leftWidgetsRaw,
                        ringSize: ringSize
                    )
                    .onTapGesture {
                        if !SettingsWindowCoordinator.exists {
                            openWindow(id: WindowsScene.settings)
                        }
                        SettingsWindowCoordinator.activate()
                    }
                    .contextMenu { contextMenuItem }
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
                                        let currentIdx = enabledDashboardTabs.firstIndex(of: dashboardTab) ?? 0
                                        let targetIdx = enabledDashboardTabs.firstIndex(of: tab) ?? 0
                                        let isAdjacent = abs(currentIdx - targetIdx) <= 1
                                        if isAdjacent {
                                            let anim: Animation = dashboardTransitionStyle == DashboardTransitionStyle.fade.rawValue
                                                ? .easeInOut(duration: 0.2)
                                                : .spring(response: 0.28, dampingFraction: 0.8)
                                            withAnimation(anim) {
                                                dashboardTab = tab
                                            }
                                        } else {
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
                        PillRightWidgetView(
                            systemMonitorViewModel: systemMonitorViewModel,
                            widgetsRaw: rightWidgetsRaw,
                            ringSize: ringSize
                        )
                        .contextMenu { contextMenuItem }
                        .opacity(dashboardOpen ? 0 : 1)
                        .scaleEffect(dashboardOpen ? 0.72 : 1, anchor: .trailing)
                        .allowsHitTesting(!dashboardOpen)

                        Button {
                            if !SettingsWindowCoordinator.exists {
                                openWindow(id: WindowsScene.settings)
                            }
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

                        // Placeholder — maintains ZStack width for layout
                        Color.clear
                            .frame(maxWidth: 220, minHeight: 28)
                            .opacity(dashboardOpen ? 1 : 0)

                        // Search bar — only in view hierarchy when apps tab is active (avoids NSTextField I-beam cursor on other tabs)
                        if dashboardOpen && dashboardTab == .apps {
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
                            .transition(.opacity)
                        }
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
    
    @ViewBuilder
    var notchSurface: some View {
        NotchBackgroundSurface(
            topCornerRadius: notchViewModel.interactiveCornerRadius.top,
            bottomCornerRadius: notchViewModel.interactiveCornerRadius.bottom
        )
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
        } else if dashboardOpen {
            Color.clear
                .frame(width: notchViewModel.notchModel.baseWidth, height: notchViewModel.notchModel.baseHeight)
        } else {
            content.makeView()
        }
    }
    
    @ViewBuilder
    var contextMenuItem: some View {
        Button {
            if !SettingsWindowCoordinator.exists {
                openWindow(id: WindowsScene.settings)
            }
            SettingsWindowCoordinator.activate()
        } label: {
            Image(systemName: "gearshape")
            Text(verbatim: localizedContextMenu("Settings", fallback: "Settings"))
        }
        
        Divider()
        
        Button(action: { AppRelauncher.restartApp() }) {
            Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
            Text(verbatim: localizedContextMenu("Restart", fallback: "Restart"))
        }
        
        Button(action: { NSApp.terminate(nil) }) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
            Text(verbatim: localizedContextMenu("Quit", fallback: "Quit"))
        }
    }
    
    private func localizedContextMenu(_ key: String, fallback: String) -> String {
        settingsViewModel.application.appLanguage.locale.dn(key, fallback: fallback)
    }
}





