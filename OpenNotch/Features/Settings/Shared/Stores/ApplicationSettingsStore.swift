import Combine
import Foundation
internal import AppKit
import ServiceManagement

@MainActor
final class ApplicationSettingsStore: SettingsStoreBase, NotchSettingsProviding {
    static let notchPressHoldDurationRange: ClosedRange<Double> = 0.20...0.60
    static let notchPressHoldDurationStep: Double = 0.01
    static let defaultNotchPressHoldDuration: TimeInterval = 0.25
    static let dashboardHoverDismissDelayRange: ClosedRange<Double> = 0.0...3.0
    static let dashboardHoverDismissDelayStep: Double = 0.1

    @Published var isLaunchAtLoginEnabled: Bool {
        didSet {
            persist(isLaunchAtLoginEnabled, for: GeneralSettingsStorage.Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    @Published var isDockIconVisible: Bool {
        didSet {
            persist(isDockIconVisible, for: GeneralSettingsStorage.Keys.dockIcon)
        }
    }

    @Published var appearanceMode: SettingsAppearanceMode {
        didSet {
            persist(appearanceMode.rawValue, for: GeneralSettingsStorage.Keys.appearanceMode)
        }
    }

    @Published var notchWidth: Int {
        didSet {
            guard oldValue != notchWidth else { return }
            persist(notchWidth, for: GeneralSettingsStorage.Keys.notchWidth)
            notchSizeEvent.send(.width)
        }
    }

    @Published var notchHeight: Int {
        didSet {
            guard oldValue != notchHeight else { return }
            persist(notchHeight, for: GeneralSettingsStorage.Keys.notchHeight)
            notchSizeEvent.send(.height)
        }
    }

    @Published var isMenuBarIconVisible: Bool {
        didSet {
            persist(isMenuBarIconVisible, for: GeneralSettingsStorage.Keys.menuBarIcon)
        }
    }

    @Published var displayLocation: NotchDisplayLocation {
        didSet {
            persist(displayLocation.rawValue, for: GeneralSettingsStorage.Keys.displayLocation)
            if displayLocation == .manual, enabledDisplayUUIDs.isEmpty {
                syncEnabledDisplayUUIDs()
            }
        }
    }

    @Published var enabledDisplayUUIDs: Set<String> {
        didSet {
            persist(Array(enabledDisplayUUIDs), for: GeneralSettingsStorage.Keys.enabledDisplayUUIDs)
        }
    }

    @Published var appLanguage: OpenNotchLanguage {
        didSet {
            persist(appLanguage.rawValue, for: GeneralSettingsStorage.Keys.appLanguage)
        }
    }

    @Published var isNotchHiddenInFullscreenEnabled: Bool {
        didSet {
            persist(
                isNotchHiddenInFullscreenEnabled,
                for: GeneralSettingsStorage.Keys.hideNotchInFullscreenEnabled
            )
        }
    }

    @Published var notchAnimationPreset: NotchAnimationPreset {
        didSet {
            persist(notchAnimationPreset.rawValue, for: GeneralSettingsStorage.Keys.notchAnimationPreset)
        }
    }

    @Published var isNotchTapToExpandEnabled: Bool {
        didSet {
            persist(isNotchTapToExpandEnabled, for: GeneralSettingsStorage.Keys.notchTapToExpandEnabled)
        }
    }

    @Published var notchExpandInteraction: NotchExpandInteraction {
        didSet {
            persist(notchExpandInteraction.rawValue, for: GeneralSettingsStorage.Keys.notchExpandInteraction)
        }
    }

    @Published var dashboardOpenMode: DashboardOpenMode {
        didSet {
            persist(dashboardOpenMode.rawValue, for: GeneralSettingsStorage.Keys.dashboardOpenMode)
        }
    }

    @Published var dashboardHoverDismissDelay: Double {
        didSet {
            let clampedValue = Self.clampDashboardHoverDismissDelay(dashboardHoverDismissDelay)

            if clampedValue != dashboardHoverDismissDelay {
                dashboardHoverDismissDelay = clampedValue
                return
            }

            persist(dashboardHoverDismissDelay, for: GeneralSettingsStorage.Keys.dashboardHoverDismissDelay)
        }
    }

    @Published var dashboardDisabledTabs: Set<String> {
        didSet {
            persist(Array(dashboardDisabledTabs), for: GeneralSettingsStorage.Keys.dashboardDisabledTabs)
        }
    }

    @Published var overviewPomodoroDuration: Int {
        didSet {
            persist(overviewPomodoroDuration, for: GeneralSettingsStorage.Keys.overviewPomodoroDuration)
        }
    }

    @Published var notchPressHoldDuration: TimeInterval {
        didSet {
            let clampedValue = Self.clampNotchPressHoldDuration(notchPressHoldDuration)

            if clampedValue != notchPressHoldDuration {
                notchPressHoldDuration = clampedValue
                return
            }

            persist(notchPressHoldDuration, for: GeneralSettingsStorage.Keys.notchPressHoldDuration)
        }
    }

    @Published var isNotchMouseDragGesturesEnabled: Bool {
        didSet {
            persist(
                isNotchMouseDragGesturesEnabled,
                for: GeneralSettingsStorage.Keys.notchMouseDragGesturesEnabled
            )
        }
    }

    @Published var isNotchTrackpadSwipeGesturesEnabled: Bool {
        didSet {
            persist(
                isNotchTrackpadSwipeGesturesEnabled,
                for: GeneralSettingsStorage.Keys.notchTrackpadSwipeGesturesEnabled
            )
        }
    }

    @Published var isNotchSwipeDismissEnabled: Bool {
        didSet {
            persist(isNotchSwipeDismissEnabled, for: GeneralSettingsStorage.Keys.notchSwipeDismissEnabled)
        }
    }

    @Published var isNotchSwipeRestoreEnabled: Bool {
        didSet {
            persist(isNotchSwipeRestoreEnabled, for: GeneralSettingsStorage.Keys.notchSwipeRestoreEnabled)
        }
    }

    @Published var notchContentPriorityOverrides: [String: Int] {
        didSet {
            let sanitizedOverrides = NotchContentPriority.sanitizedOverrides(notchContentPriorityOverrides)

            guard sanitizedOverrides == notchContentPriorityOverrides else {
                notchContentPriorityOverrides = sanitizedOverrides
                return
            }

            persist(
                notchContentPriorityOverrides,
                for: GeneralSettingsStorage.Keys.notchContentPriorityOverrides
            )
            NotificationCenter.default.post(name: .notchContentPrioritiesDidChange, object: self)
        }
    }

    @Published var isNotchSizeTemporaryActivityEnabled: Bool {
        didSet {
            persist(
                isNotchSizeTemporaryActivityEnabled,
                for: GeneralSettingsStorage.Keys.notchSizeTemporaryActivityEnabled
            )
        }
    }

    @Published var notchSizeTemporaryActivityDuration: Int {
        didSet {
            let clampedValue = Self.clampTemporaryActivityDuration(notchSizeTemporaryActivityDuration)
            if clampedValue != notchSizeTemporaryActivityDuration {
                notchSizeTemporaryActivityDuration = clampedValue
                return
            }

            persist(
                notchSizeTemporaryActivityDuration,
                for: GeneralSettingsStorage.Keys.notchSizeTemporaryActivityDuration
            )
        }
    }

    let notchSizeEvent = PassthroughSubject<NotchSizeEvent, Never>()

    var screenSelectionPreferences: NotchScreenSelectionPreferences {
        NotchScreenSelectionPreferences(
            displayLocation: displayLocation,
            enabledDisplayUUIDs: enabledDisplayUUIDs
        )
    }

    override init(defaults: UserDefaults) {
        self.isLaunchAtLoginEnabled = defaults.bool(forKey: GeneralSettingsStorage.Keys.launchAtLogin)
        self.isDockIconVisible = defaults.bool(forKey: GeneralSettingsStorage.Keys.dockIcon)
        self.appearanceMode = SettingsAppearanceMode.resolved(
            defaults.string(forKey: GeneralSettingsStorage.Keys.appearanceMode)
        )
        self.notchWidth = defaults.integer(forKey: GeneralSettingsStorage.Keys.notchWidth)
        self.notchHeight = defaults.integer(forKey: GeneralSettingsStorage.Keys.notchHeight)
        self.isMenuBarIconVisible = defaults.bool(forKey: GeneralSettingsStorage.Keys.menuBarIcon)
        self.displayLocation = NotchDisplayLocation(
            rawValue: defaults.string(forKey: GeneralSettingsStorage.Keys.displayLocation) ?? NotchDisplayLocation.auto.rawValue
        ) ?? .auto
        self.enabledDisplayUUIDs = Set(
            defaults.stringArray(forKey: GeneralSettingsStorage.Keys.enabledDisplayUUIDs) ?? []
        )
        self.appLanguage = OpenNotchLanguage.resolved(
            defaults.string(forKey: GeneralSettingsStorage.Keys.appLanguage)
        )
        self.isNotchHiddenInFullscreenEnabled = Self.resolvedBool(
            defaults: defaults,
            key: GeneralSettingsStorage.Keys.hideNotchInFullscreenEnabled
        )
        self.notchAnimationPreset = NotchAnimationPreset(
            rawValue: defaults.string(forKey: GeneralSettingsStorage.Keys.notchAnimationPreset) ?? NotchAnimationPreset.balanced.rawValue
        ) ?? .balanced
        self.isNotchTapToExpandEnabled = Self.resolvedBool(
            defaults: defaults,
            key: GeneralSettingsStorage.Keys.notchTapToExpandEnabled
        )
        self.notchExpandInteraction = NotchExpandInteraction.resolved(
            defaults.string(forKey: GeneralSettingsStorage.Keys.notchExpandInteraction)
        )
        self.dashboardOpenMode = DashboardOpenMode.resolved(
            defaults.string(forKey: GeneralSettingsStorage.Keys.dashboardOpenMode)
        )
        self.dashboardHoverDismissDelay = Self.clampDashboardHoverDismissDelay(
            defaults.object(forKey: GeneralSettingsStorage.Keys.dashboardHoverDismissDelay) as? Double ??
            (GeneralSettingsStorage.defaultValues[GeneralSettingsStorage.Keys.dashboardHoverDismissDelay] as? Double ?? 0.6)
        )
        self.dashboardDisabledTabs = Set(
            defaults.stringArray(forKey: GeneralSettingsStorage.Keys.dashboardDisabledTabs) ?? []
        )
        self.overviewPomodoroDuration = defaults.object(forKey: GeneralSettingsStorage.Keys.overviewPomodoroDuration) as? Int ?? 25
        self.notchPressHoldDuration = Self.clampNotchPressHoldDuration(
            defaults.object(forKey: GeneralSettingsStorage.Keys.notchPressHoldDuration) as? Double ??
            Self.defaultNotchPressHoldDuration
        )
        self.isNotchMouseDragGesturesEnabled = Self.resolvedBool(
            defaults: defaults,
            key: GeneralSettingsStorage.Keys.notchMouseDragGesturesEnabled
        )
        self.isNotchTrackpadSwipeGesturesEnabled = Self.resolvedBool(
            defaults: defaults,
            key: GeneralSettingsStorage.Keys.notchTrackpadSwipeGesturesEnabled
        )
        self.isNotchSwipeDismissEnabled = Self.resolvedBool(
            defaults: defaults,
            key: GeneralSettingsStorage.Keys.notchSwipeDismissEnabled
        )
        self.isNotchSwipeRestoreEnabled = Self.resolvedBool(
            defaults: defaults,
            key: GeneralSettingsStorage.Keys.notchSwipeRestoreEnabled
        )
        self.notchContentPriorityOverrides = NotchContentPriority.overrideValues(defaults: defaults)
        self.isNotchSizeTemporaryActivityEnabled = defaults.bool(forKey: GeneralSettingsStorage.Keys.notchSizeTemporaryActivityEnabled)
        self.notchSizeTemporaryActivityDuration = Self.clampTemporaryActivityDuration(
            defaults.object(forKey: GeneralSettingsStorage.Keys.notchSizeTemporaryActivityDuration) as? Int ??
            Self.defaultTemporaryActivityDuration(for: GeneralSettingsStorage.Keys.notchSizeTemporaryActivityDuration)
        )
        super.init(defaults: defaults)
        updateLaunchAtLogin()
    }

    func resetGeneral() {
        isLaunchAtLoginEnabled = defaultBool(for: GeneralSettingsStorage.Keys.launchAtLogin)
        isDockIconVisible = defaultBool(for: GeneralSettingsStorage.Keys.dockIcon)
        appearanceMode = SettingsAppearanceMode.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.appearanceMode)
        )
        isMenuBarIconVisible = defaultBool(for: GeneralSettingsStorage.Keys.menuBarIcon)
        displayLocation = NotchDisplayLocation(
            rawValue: defaultString(for: GeneralSettingsStorage.Keys.displayLocation)
        ) ?? .auto
        enabledDisplayUUIDs = []
        appLanguage = OpenNotchLanguage.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.appLanguage)
        )
        isNotchHiddenInFullscreenEnabled = defaultBool(
            for: GeneralSettingsStorage.Keys.hideNotchInFullscreenEnabled
        )
        dashboardOpenMode = DashboardOpenMode.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.dashboardOpenMode)
        )
        dashboardHoverDismissDelay = defaultDouble(for: GeneralSettingsStorage.Keys.dashboardHoverDismissDelay)
        dashboardDisabledTabs = []
    }

    func resetNotch() {
        notchAnimationPreset = NotchAnimationPreset(
            rawValue: defaultString(for: GeneralSettingsStorage.Keys.notchAnimationPreset)
        ) ?? .balanced
        isNotchTapToExpandEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchTapToExpandEnabled)
        notchExpandInteraction = NotchExpandInteraction.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.notchExpandInteraction)
        )
        notchPressHoldDuration = Self.clampNotchPressHoldDuration(
            defaultDouble(for: GeneralSettingsStorage.Keys.notchPressHoldDuration)
        )
        isNotchMouseDragGesturesEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchMouseDragGesturesEnabled)
        isNotchTrackpadSwipeGesturesEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchTrackpadSwipeGesturesEnabled)
        isNotchSwipeDismissEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchSwipeDismissEnabled)
        isNotchSwipeRestoreEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchSwipeRestoreEnabled)
        resetNotchContentPriorities()
        isNotchSizeTemporaryActivityEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchSizeTemporaryActivityEnabled)
        notchSizeTemporaryActivityDuration = Self.clampTemporaryActivityDuration(
            defaultInt(for: GeneralSettingsStorage.Keys.notchSizeTemporaryActivityDuration)
        )
        notchWidth = defaultInt(for: GeneralSettingsStorage.Keys.notchWidth)
        notchHeight = defaultInt(for: GeneralSettingsStorage.Keys.notchHeight)
    }

    private static func clampDashboardHoverDismissDelay(_ value: Double) -> Double {
        min(
            max(value, dashboardHoverDismissDelayRange.lowerBound),
            dashboardHoverDismissDelayRange.upperBound
        )
    }

    func reset() {
        resetGeneral()
        resetNotch()
    }

    func notchContentPriority(for key: NotchContentPriority.Key) -> Int {
        notchContentPriorityOverrides[key.rawValue] ?? key.defaultValue
    }

    func setNotchContentPriority(_ priority: Int, for key: NotchContentPriority.Key) {
        let clampedPriority = NotchContentPriority.clamped(priority)
        var overrides = notchContentPriorityOverrides

        if clampedPriority == key.defaultValue {
            overrides.removeValue(forKey: key.rawValue)
        } else {
            overrides[key.rawValue] = clampedPriority
        }

        notchContentPriorityOverrides = overrides
    }

    func resetNotchContentPriorities() {
        notchContentPriorityOverrides = [:]
    }

    private static func resolvedBool(defaults: UserDefaults, key: String) -> Bool {
        if let currentValue = defaults.object(forKey: key) as? Bool {
            return currentValue
        }

        return (GeneralSettingsStorage.defaultValues[key] as? Bool) ?? false
    }

    private static func clampNotchPressHoldDuration(_ value: TimeInterval) -> TimeInterval {
        min(
            max(value, notchPressHoldDurationRange.lowerBound),
            notchPressHoldDurationRange.upperBound
        )
    }

    private func updateLaunchAtLogin() {
        let instance = SMAppService.mainApp

        do {
            if isLaunchAtLoginEnabled {
                try instance.register()
            } else {
                try instance.unregister()
            }
        } catch {
            print("Ошибка для \(instance.description): \(error)")
        }
    }

    func toggleDisplayUUID(_ uuid: String) {
        if enabledDisplayUUIDs.contains(uuid) {
            guard enabledDisplayUUIDs.count > 1 else { return }
            enabledDisplayUUIDs.remove(uuid)
        } else {
            enabledDisplayUUIDs.insert(uuid)
        }
    }

    func syncEnabledDisplayUUIDs() {
        let available = NSScreen.availableNotchDisplays()
        let availableUUIDs = Set(available.map(\.displayUUID))
        enabledDisplayUUIDs = enabledDisplayUUIDs.intersection(availableUUIDs)
        if enabledDisplayUUIDs.isEmpty, let first = available.first {
            enabledDisplayUUIDs.insert(first.displayUUID)
        }
    }
}
