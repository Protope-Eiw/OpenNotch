import SwiftUI

extension AppDelegate {
    func createNotchWindow() {
        if window != nil {
            window.orderOut(nil)
            window.contentView = nil
            window = nil
        }
        destroyNotchWindows()

        let displayLocation = settingsViewModel.application.displayLocation

        switch displayLocation {
        case .auto:
            createAutoNotchWindow()
        case .manual:
            createManualNotchWindows()
        }
    }

    @objc
    func updateWindowFrame() {
        let displayLocation = settingsViewModel.application.displayLocation

        switch displayLocation {
        case .auto:
            if !notchWindows.isEmpty {
                destroyNotchWindows()
            }
            if window == nil {
                createAutoNotchWindow()
            } else {
                updateAutoWindowFrame()
            }
        case .manual:
            if window != nil {
                window.orderOut(nil)
                window.contentView = nil
                window = nil
            }
            if notchWindows.isEmpty {
                createManualNotchWindows()
            } else {
                updateManualWindowFrames()
            }
        }
    }

    func startMousePolling() {
        stopMousePolling()
        mousePollingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, settingsViewModel.application.displayLocation == .auto else { return }
                checkMouseScreenChange()
            }
        }
    }

    func stopMousePolling() {
        mousePollingTimer?.invalidate()
        mousePollingTimer = nil
    }

    private func checkMouseScreenChange() {
        guard let mouseScreen = NSScreen.screenWithMouse,
              let mouseScreenID = mouseScreen.displayID else { return }

        if mouseScreenID != lastMouseScreenID {
            lastMouseScreenID = mouseScreenID
            updateAutoWindowFrame()
        }
    }

    func suspendPrimaryWindowForLock() {
        let displayLocation = settingsViewModel.application.displayLocation

        switch displayLocation {
        case .auto:
            suspendAutoWindowForLock()
        case .manual:
            suspendManualWindowsForLock()
        }
    }

    func restorePrimaryWindowForUnlockTransition() {
        guard isPrimaryWindowSuspendedForLock else { return }

        isPrimaryWindowSuspendedForLock = false
        updateWindowFrame()
    }

    func destroyNotchWindows() {
        for (_, window) in notchWindows {
            window.orderOut(nil)
            window.contentView = nil
        }
        notchWindows.removeAll()
        notchViewModels.removeAll()
    }

    // MARK: - Auto Mode

    private func createAutoNotchWindow() {
        guard let screen = NSScreen.screenWithMouse ?? NSScreen.screens.first else { return }

        lastMouseScreenID = screen.displayID

        let frame = OverlayWindowLayout.topAnchoredFrame(
            on: screen,
            size: OverlayWindowLayout.appCanvasSize
        )

        window = OverlayPanelFactory.makePanel(
            frame: frame,
            level: OverlayWindowLevel.interactiveNotch
        )

        let hostingView = NotchHostingView(
            rootView: NotchView(
                notchViewModel: notchViewModel,
                notchEventCoordinator: notchEventCoordinator,
                powerViewModel: powerViewModel,
                bluetoothViewModel: bluetoothViewModel,
                networkViewModel: networkViewModel,
                downloadViewModel: downloadViewModel,
                focusViewModel: focusViewModel,
                airDropViewModel: airDropViewModel,
                airDropController: airDropController,
                settingsViewModel: settingsViewModel,
                nowPlayingViewModel: nowPlayingViewModel,
                timerViewModel: timerViewModel,
                screenRecordingViewModel: screenRecordingViewModel,
                lockScreenManager: lockScreenManager,
                systemMonitorViewModel: container.systemMonitorViewModel
            )
        )

        window.contentView = hostingView
        window.collectionBehavior = OverlayPanelFactory.collectionBehavior(
            includesFullscreenAuxiliary: true
        )
        SkyLightOperator.shared.delegateWindow(window, to: .notchSurface)
        updateAutoWindowFrame()
    }

    private func updateAutoWindowFrame() {
        guard let window else { return }

        notchViewModel.updateDimensionsForDisplayTransition()

        guard let screen = NSScreen.screenWithMouse ?? NSScreen.screens.first else {
            clearNowPlayingPrimaryWindowPresentationState()
            window.orderOut(nil)
            return
        }

        let targetFrame = OverlayWindowLayout.topAnchoredFrame(
            on: screen,
            size: window.frame.size
        )

        window.collectionBehavior = OverlayPanelFactory.collectionBehavior(
            includesFullscreenAuxiliary: true
        )
        window.setFrame(targetFrame, display: true, animate: false)
        updatePrimaryWindowPresentation(on: screen)
    }

    private func suspendAutoWindowForLock() {
        guard let window, !isPrimaryWindowSuspendedForLock else { return }

        isPrimaryWindowSuspendedForLock = true
        clearNowPlayingPrimaryWindowPresentationState()
        window.orderOut(nil)
    }

    // MARK: - Manual Mode

    private func createManualNotchWindows() {
        let screens = NSScreen.preferredNotchScreens(for: settingsViewModel)
        guard !screens.isEmpty else { return }

        for screen in screens {
            guard let displayID = screen.displayID else { continue }
            if notchWindows[displayID] != nil { continue }

            let frame = OverlayWindowLayout.topAnchoredFrame(
                on: screen,
                size: OverlayWindowLayout.appCanvasSize
            )

            let window = OverlayPanelFactory.makePanel(
                frame: frame,
                level: OverlayWindowLevel.interactiveNotch
            )

            let viewModel: NotchViewModel
            if notchWindows.isEmpty {
                viewModel = notchViewModel
            } else {
                viewModel = NotchViewModel(
                    settings: settingsViewModel.application,
                    screen: screen
                )
            }

            let hostingView = NotchHostingView(
                rootView: NotchView(
                    notchViewModel: viewModel,
                    notchEventCoordinator: notchEventCoordinator,
                    powerViewModel: powerViewModel,
                    bluetoothViewModel: bluetoothViewModel,
                    networkViewModel: networkViewModel,
                    downloadViewModel: downloadViewModel,
                    focusViewModel: focusViewModel,
                    airDropViewModel: airDropViewModel,
                    airDropController: airDropController,
                    settingsViewModel: settingsViewModel,
                    nowPlayingViewModel: nowPlayingViewModel,
                    timerViewModel: timerViewModel,
                    screenRecordingViewModel: screenRecordingViewModel,
                    lockScreenManager: lockScreenManager,
                    systemMonitorViewModel: container.systemMonitorViewModel
                )
            )

            window.contentView = hostingView
            window.collectionBehavior = OverlayPanelFactory.collectionBehavior(
                includesFullscreenAuxiliary: true
            )
            SkyLightOperator.shared.delegateWindow(window, to: .notchSurface)

            notchWindows[displayID] = window
            if viewModel !== notchViewModel {
                notchViewModels[displayID] = viewModel
            }
        }

        updateManualWindowFrames()
    }

    private func updateManualWindowFrames() {
        let screens = NSScreen.preferredNotchScreens(for: settingsViewModel)
        let currentIDs = Set(notchWindows.keys)
        let existingIDs = Set(screens.compactMap(\.displayID))

        for removedID in currentIDs.subtracting(existingIDs) {
            notchWindows[removedID]?.orderOut(nil)
            notchWindows[removedID]?.contentView = nil
            notchWindows.removeValue(forKey: removedID)
            notchViewModels.removeValue(forKey: removedID)
        }

        for screen in screens {
            guard let displayID = screen.displayID else { continue }

            if let existingWindow = notchWindows[displayID] {
                let viewModel = notchViewModels[displayID] ?? notchViewModel
                viewModel.updateDimensionsForDisplayTransition()

                let targetFrame = OverlayWindowLayout.topAnchoredFrame(
                    on: screen,
                    size: existingWindow.frame.size
                )
                existingWindow.setFrame(targetFrame, display: true, animate: false)
                existingWindow.orderFrontRegardless()
            } else {
                let frame = OverlayWindowLayout.topAnchoredFrame(
                    on: screen,
                    size: OverlayWindowLayout.appCanvasSize
                )

                let window = OverlayPanelFactory.makePanel(
                    frame: frame,
                    level: OverlayWindowLevel.interactiveNotch
                )

                let viewModel = NotchViewModel(
                    settings: settingsViewModel.application,
                    screen: screen
                )

                let hostingView = NotchHostingView(
                    rootView: NotchView(
                        notchViewModel: viewModel,
                        notchEventCoordinator: notchEventCoordinator,
                        powerViewModel: powerViewModel,
                        bluetoothViewModel: bluetoothViewModel,
                        networkViewModel: networkViewModel,
                        downloadViewModel: downloadViewModel,
                        focusViewModel: focusViewModel,
                        airDropViewModel: airDropViewModel,
                        airDropController: airDropController,
                        settingsViewModel: settingsViewModel,
                        nowPlayingViewModel: nowPlayingViewModel,
                        timerViewModel: timerViewModel,
                        screenRecordingViewModel: screenRecordingViewModel,
                        lockScreenManager: lockScreenManager,
                        systemMonitorViewModel: container.systemMonitorViewModel
                    )
                )

                window.contentView = hostingView
                window.collectionBehavior = OverlayPanelFactory.collectionBehavior(
                    includesFullscreenAuxiliary: true
                )
                SkyLightOperator.shared.delegateWindow(window, to: .notchSurface)

                window.orderFrontRegardless()

                notchWindows[displayID] = window
                notchViewModels[displayID] = viewModel
            }
        }
    }

    private func suspendManualWindowsForLock() {
        guard !isPrimaryWindowSuspendedForLock else { return }

        isPrimaryWindowSuspendedForLock = true
        clearNowPlayingPrimaryWindowPresentationState()

        for (_, window) in notchWindows {
            window.orderOut(nil)
        }
    }

    // MARK: - Shared

    private func updatePrimaryWindowPresentation(on screen: NSScreen) {
        guard !isPrimaryWindowSuspendedForLock else { return }

        switch settingsViewModel.application.displayLocation {
        case .auto:
            applyPresentationState(viewModel: notchViewModel, window: window, on: screen)
        case .manual:
            guard let mouseScreen = NSScreen.screenWithMouse ?? NSScreen.screens.first,
                  let mouseID = mouseScreen.displayID,
                  let activeWindow = notchWindows[mouseID] ?? notchWindows.values.first else {
                return
            }
            let activeViewModel = notchViewModels[mouseID] ?? notchViewModel
            applyPresentationState(viewModel: activeViewModel, window: activeWindow, on: screen)
        }
    }

    private func applyPresentationState(viewModel: NotchViewModel, window: OverlayPanelWindow?, on screen: NSScreen) {
        guard let window else { return }

        let shouldHideActivities = shouldHidePrimaryWindowActivitiesInFullscreen(on: screen)
        viewModel.setActivityPresentationHidden(shouldHideActivities)

        if shouldHideActivities {
            clearNowPlayingPrimaryWindowPresentationState()
        }

        window.orderFrontRegardless()
    }

    private func shouldHidePrimaryWindowActivitiesInFullscreen(on screen: NSScreen) -> Bool {
        settingsViewModel.application.isNotchHiddenInFullscreenEnabled &&
        SkyLightOperator.shared.isFullscreenSpaceActive(on: screen)
    }

    private func clearNowPlayingPrimaryWindowPresentationState() {
        nowPlayingViewModel.clearPresentationActivityState()
    }
}
