import SwiftUI
import Combine
import EventKit

struct DebugSettingsView: View {
    @ObservedObject var viewModel: DebugSettingsViewModel

    @State private var calEventAuth = ""
    @State private var calReminderAuth = ""
    @State private var calCount = ""
    @State private var calWarmupResult = ""
    @State private var calWarmupError = ""

    var body: some View {
        SettingsPageScrollView {
            persistentPreviewsCard
            triggerEventsCard
            utilitiesCard
            calendarDiagnosticCard
        }
        .accessibilityIdentifier("settings.debug.root")
        .onAppear(perform: checkCalendarNow)
    }
    
    private var persistentPreviewsCard: some View {
        SettingsCard(title: "Persistent Events") {
            SettingsToggleRow(
                title: "Onboarding",
                description: "Show a safe debug preview of the onboarding live activity.",
                systemImage: "sparkles.rectangle.stack",
                color: .pink,
                isOn: $viewModel.isOnboardingPreviewEnabled,
                accessibilityIdentifier: "settings.debug.onboarding"
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: "Focus On",
                description: "Preview the persistent Focus live activity.",
                systemImage: "moon.fill",
                color: .indigo,
                isOn: $viewModel.isFocusLivePreviewEnabled,
                accessibilityIdentifier: "settings.debug.focusOn"
            )

            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

            SettingsToggleRow(
                title: "Screen Recording",
                description: "Preview the persistent screen recording indicator.",
                systemImage: "record.circle.fill",
                color: .red,
                isOn: $viewModel.isScreenRecordingPreviewEnabled,
                accessibilityIdentifier: "settings.debug.screenRecording"
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: "Hotspot Active",
                description: "Keep the hotspot live activity visible until you turn it off.",
                systemImage: "personalhotspot",
                color: .green,
                isOn: $viewModel.isHotspotPreviewEnabled,
                accessibilityIdentifier: "settings.debug.hotspot"
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: "Now Playing",
                description: "Show the music live activity with sample track data.",
                systemImage: "music.note",
                color: .orange,
                isOn: $viewModel.isNowPlayingPreviewEnabled,
                accessibilityIdentifier: "settings.debug.nowPlaying"
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: "Downloads",
                description: "Show the download live activity with sample transfer data.",
                systemImage: "arrow.down.doc.fill",
                color: .blue,
                isOn: $viewModel.isDownloadPreviewEnabled,
                accessibilityIdentifier: "settings.debug.downloads"
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: "Timer",
                description: "Show the timer live activity with sample transfer data.",
                systemImage: "gauge.with.needle",
                color: .orange,
                isOn: $viewModel.isTimerPreviewEnabled,
                accessibilityIdentifier: "settings.debug.timer"
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: "Lock Screen",
                description: "Preview the lock live activity without actually locking macOS.",
                systemImage: "lock.fill",
                color: .black,
                isOn: $viewModel.isLockScreenPreviewEnabled,
                accessibilityIdentifier: "settings.debug.lockScreen"
            )
        }
    }
    
    private var triggerEventsCard: some View {
        SettingsCard(title: "Trigger Events") {
            DebugActionRow(
                title: "Play All Events",
                description: "Run every debug event in sequence, keep each item visible for its configured duration, wait 1 second between items, and skip onboarding, notch size, and lock screen previews.",
                systemImage: viewModel.isPreviewSequenceRunning ? "stop.circle.fill" : "play.circle.fill",
                color: .accentColor,
                buttonTitle: viewModel.isPreviewSequenceRunning ? LocalizedStringKey("Stop") : LocalizedStringKey("Start"),
                action: viewModel.togglePreviewSequence
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            DebugActionRow(
                title: "Focus Off",
                description: "Hide the Focus live activity and show the short \"Off\" notification.",
                systemImage: "moon.zzz.fill",
                color: .gray,
                action: viewModel.triggerFocusOffPreview
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            DebugActionRow(
                title: "Bluetooth Connected",
                description: "Show the Bluetooth notification with sample AirPods data.",
                systemImage: "bolt.horizontal.circle.fill",
                color: .blue,
                action: viewModel.triggerBluetoothPreview
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            DebugActionRow(
                title: "Wi-Fi Connected",
                description: "Shows the Wi-Fi temporary notification.",
                systemImage: "wifi",
                color: .blue,
                action: viewModel.triggerWifiPreview
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

            DebugActionRow(
                title: "No Internet Connection",
                description: "Show the offline temporary notification with its actions.",
                systemImage: "wifi.slash",
                color: .red,
                action: viewModel.triggerNoInternetConnectionPreview
            )

            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            DebugActionRow(
                title: "VPN Connected",
                description: "Show the VPN notification with sample tunnel data.",
                systemImage: "network.badge.shield.half.filled",
                color: .blue,
                action: viewModel.triggerVPNPreview
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            DebugActionRow(
                title: "Charging",
                description: "Apply a sample charging state and show the charger notification.",
                systemImage: "battery.75",
                color: .green,
                action: viewModel.triggerChargingPreview
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            DebugActionRow(
                title: "Battery Low",
                description: "Apply a low battery sample and show the low-power alert.",
                systemImage: "battery.25",
                color: .red,
                action: viewModel.triggerLowPowerPreview
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            DebugActionRow(
                title: "Full Battery",
                description: "Apply a full battery sample and show the completion notification.",
                systemImage: "battery.100percent",
                color: .green,
                action: viewModel.triggerFullBatteryPreview
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            DebugActionRow(
                title: "Brightness HUD",
                description: "Show the brightness HUD preview at 72%.",
                systemImage: "sun.max.fill",
                color: .yellow,
                action: viewModel.triggerBrightnessHUDPreview
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            DebugActionRow(
                title: "Keyboard HUD",
                description: "Show the keyboard backlight HUD preview at 64%.",
                systemImage: "light.max",
                color: .mint,
                action: viewModel.triggerKeyboardHUDPreview
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            DebugActionRow(
                title: "Volume HUD",
                description: "Show the volume HUD preview at 42%.",
                systemImage: "speaker.wave.2.fill",
                color: .purple,
                action: viewModel.triggerVolumeHUDPreview
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            DebugActionRow(
                title: "Notch Width Changed",
                description: "Show the width resize helper using the current settings.",
                systemImage: "arrow.left.and.right",
                color: .red,
                action: viewModel.triggerNotchWidthPreview
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            DebugActionRow(
                title: "Notch Height Changed",
                description: "Show the height resize helper using the current settings.",
                systemImage: "arrow.up.and.down",
                color: .red,
                action: viewModel.triggerNotchHeightPreview
            )
        }
    }
    
    private var utilitiesCard: some View {
        SettingsCard(title: "Utilities") {
            DebugActionRow(
                title: "Hide Current Temporary",
                description: "Dismiss the currently visible temporary notification.",
                systemImage: "eye.slash.fill",
                color: .gray,
                action: viewModel.hideCurrentTemporaryPreview
            )
            
            SettingsDivider()
            
            DebugActionRow(
                title: "Reset All Previews",
                description: "Turn off every persistent preview and close any temporary content.",
                systemImage: "arrow.counterclockwise.circle.fill",
                color: .red,
                action: viewModel.resetAllPreviews
            )
        }
    }

    private var calendarDiagnosticCard: some View {
        SettingsCard(title: "Calendar Permission Diagnostic") {
            VStack(spacing: 4) {
                statusRow(label: "Event Auth", value: calEventAuth)
                statusRow(label: "Reminder Auth", value: calReminderAuth)
                statusRow(label: "Calendars Found", value: calCount)
            }
            .padding(.vertical, 6)

            if !calWarmupResult.isEmpty || !calWarmupError.isEmpty {
                SettingsDivider()
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: calWarmupError.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundStyle(calWarmupError.isEmpty ? .green : .red)
                        Text(calWarmupResult)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(calWarmupError.isEmpty ? .green : .red)
                    }
                    if !calWarmupError.isEmpty {
                        Text(calWarmupError)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.red)
                            .lineLimit(3)
                    }
                }
                .padding(.vertical, 4)
            }

            SettingsDivider()

            DebugActionRow(
                title: "Re-check Status",
                description: "Read current EKEventStore authorization status.",
                systemImage: "arrow.clockwise.circle.fill",
                color: .gray,
                buttonTitle: "Check",
                action: checkCalendarNow
            )

            SettingsDivider()

            DebugActionRow(
                title: "Warm-up EventKit",
                description: "Call requestFullAccessToEvents() to refresh TCC state.",
                systemImage: "bolt.fill",
                color: .orange,
                buttonTitle: "Warm Up",
                action: warmUpCalendar
            )

            SettingsDivider()

            DebugActionRow(
                title: "Force Read Calendar",
                description: "Create fresh EKEventStore and attempt full calendar read.",
                systemImage: "text.magnifyingglass",
                color: .blue,
                buttonTitle: "Test Read",
                action: forceReadCalendar
            )

            SettingsDivider()

            DebugActionRow(
                title: "Open System Settings",
                description: "Jump to Calendar privacy pane.",
                systemImage: "gear",
                color: .gray,
                buttonTitle: "Open",
                action: { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!) }
            )

            SettingsDivider()

            DebugActionRow(
                title: "Reset TCC Calendar Permission",
                description: "Run 'tccutil reset Calendar' to clear stale permission entry.",
                systemImage: "trash.circle.fill",
                color: .red,
                buttonTitle: "Reset",
                action: resetCalendarTCC
            )
        }
    }

    @ViewBuilder
    private func statusRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    value == "fullAccess ✓" ? Color.green :
                    value == "notDetermined" ? Color.yellow :
                    value == "denied" ? Color.red :
                    .white.opacity(0.85)
                )
        }
    }

    private func statusString(_ s: EKAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "notDetermined"
        case .restricted:    return "restricted"
        case .denied:        return "denied"
        case .fullAccess:    return "fullAccess ✓"
        case .writeOnly:     return "writeOnly"
        @unknown default:    return "unknown"
        }
    }

    private func checkCalendarNow() {
        calEventAuth = statusString(EKEventStore.authorizationStatus(for: .event))
        calReminderAuth = statusString(EKEventStore.authorizationStatus(for: .reminder))
        let s = EKEventStore.authorizationStatus(for: .event)
        if s == .fullAccess || s == .writeOnly {
            calCount = "\(EKEventStore.app.calendars(for: .event).count)"
        } else {
            calCount = "—"
        }
    }

    private func warmUpCalendar() {
        calWarmupResult = "Trying async API…"
        calWarmupError = ""
        let store = EKEventStore()
        Task {
            do {
                let granted = try await store.requestFullAccessToEvents()
                calWarmupResult = "async API: \(granted ? "Granted" : "Denied")"
                checkCalendarNow()
            } catch {
                let nsError = error as NSError
                calWarmupResult = "async API threw"
                calWarmupError = "domain=\(nsError.domain) code=\(nsError.code) desc=\(nsError.localizedDescription)"
                tryCompletionAPI(store: store)
            }
        }
    }

    private func tryCompletionAPI(store: EKEventStore) {
        calWarmupResult = "Trying completion API…"
        store.requestAccess(to: .event) { [self] granted, error in
            DispatchQueue.main.async {
                if let err = error as? NSError {
                    self.calWarmupResult = "completion API threw"
                    self.calWarmupError = "domain=\(err.domain) code=\(err.code) desc=\(err.localizedDescription)"
                } else if let err = error {
                    self.calWarmupResult = "completion API threw"
                    self.calWarmupError = String(describing: err)
                } else {
                    self.calWarmupResult = "completion API: \(granted ? "Granted" : "Denied")"
                }
                self.checkCalendarNow()
            }
        }
    }

    private func forceReadCalendar() {
        calWarmupResult = "Trying fresh store…"
        calWarmupError = ""
        let store = EKEventStore()
        Task {
            do {
                let granted = try await store.requestFullAccessToEvents()
                if granted {
                    readFromStore(store, label: "fresh+granted")
                } else {
                    calWarmupResult = "fresh store denied"
                    readFromStore(store, label: "fresh+denied")
                }
            } catch {
                let nsError = error as NSError
                calWarmupResult = "fresh async API threw"
                calWarmupError = "domain=\(nsError.domain) code=\(nsError.code) desc=\(nsError.localizedDescription)"
                store.requestAccess(to: .event) { [self] granted, error in
                    DispatchQueue.main.async {
                        if let err = error as? NSError {
                            self.calWarmupResult = "fresh+completion threw"
                            self.calWarmupError = "domain=\(err.domain) code=\(err.code) desc=\(err.localizedDescription)"
                        } else if let err = error {
                            self.calWarmupResult = "fresh+completion threw"
                            self.calWarmupError = String(describing: err)
                        } else {
                            self.calWarmupResult = "fresh+completion: \(granted ? "Granted" : "Denied")"
                            if granted { self.readFromStore(store, label: "fresh+completion") }
                        }
                        self.checkCalendarNow()
                    }
                }
            }
        }
    }

    private func readFromStore(_ store: EKEventStore, label: String) {
        let cals = store.calendars(for: .event)
        let pred = store.predicateForEvents(
            withStart: Date().addingTimeInterval(-86400 * 30),
            end: Date().addingTimeInterval(86400),
            calendars: nil
        )
        let events = store.events(matching: pred)
        calWarmupResult = "\(label): \(cals.count) cals, \(events.count) events"
    }

    private func resetCalendarTCC() {
        calWarmupResult = "Resetting TCC…"
        calWarmupError = ""
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["tccutil", "reset", "Calendar", "com.Jackson.OpenNotch"]
        task.terminationHandler = { [self] process in
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    calWarmupResult = "TCC reset OK. Try Check or Warm Up again."
                } else {
                    calWarmupResult = "TCC reset failed (status \(process.terminationStatus))"
                    calWarmupError = "Run manually: tccutil reset Calendar com.Jackson.OpenNotch"
                }
            }
        }
        do {
            try task.run()
        } catch {
            calWarmupResult = "Could not launch tccutil"
            calWarmupError = error.localizedDescription
        }
    }
}

struct DebugActionRow: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let systemImage: String
    let color: Color
    let buttonTitle: LocalizedStringKey
    let action: () -> Void
    
    init(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        systemImage: String,
        color: Color,
        buttonTitle: LocalizedStringKey = "Start",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.systemImage = systemImage
        self.color = color
        self.buttonTitle = buttonTitle
        self.action = action
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.gradient)
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 16)
            
            Button(buttonTitle, action: action)
                .controlSize(.small)
        }
    }
}

// Wraps preview content in a debug-only identity so the sequence does not evict
// the app's real live activities that reuse the same content types.
struct DebugSequenceNotchContent: NotchContentProtocol {
    let id: String
    let priority: Int
    let base: any NotchContentProtocol
    
    var strokeColor: Color { base.strokeColor }
    var isExpandable: Bool { base.isExpandable }
    var expandsOnTap: Bool { base.expandsOnTap }
    var windowLink: (@MainActor () -> Void)? { base.windowLink }
    
    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        base.size(baseWidth: baseWidth, baseHeight: baseHeight)
    }
    
    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        base.expandedSize(baseWidth: baseWidth, baseHeight: baseHeight)
    }
    
    func cornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        base.cornerRadius(baseRadius: baseRadius)
    }
    
    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        base.expandedCornerRadius(baseRadius: baseRadius)
    }
    
    @MainActor
    func makeView() -> AnyView {
        base.makeView()
    }
    
    @MainActor
    func makeExpandedView() -> AnyView {
        base.makeExpandedView()
    }
}

struct DebugOnboardingPreviewNotchContent: NotchContentProtocol {
    let id: String
    let stackID = NotchContentRegistry.Onboarding.debugStackID
    let step: OnboardingSteps
    let notchEventCoordinator: NotchEventCoordinator
    
    var priority: Int { NotchContentRegistry.Onboarding.priority }
    
    init(step: OnboardingSteps, notchEventCoordinator: NotchEventCoordinator) {
        self.id = step.debugLiveActivityID
        self.step = step
        self.notchEventCoordinator = notchEventCoordinator
    }
    
    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        step.notchSize(baseWidth: baseWidth, baseHeight: baseHeight)
    }
    
    func cornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        return (top: 24, bottom: 36)
    }
    
    @MainActor
    func makeView() -> AnyView {
        AnyView(
            OnboardingNotchView(
                step: step,
                onStepChange: { nextStep in
                    notchEventCoordinator.showDebugOnboardingPreview(step: nextStep)
                },
                onFinish: {
                    notchEventCoordinator.hideOnboarding()
                }
            )
        )
    }
}
