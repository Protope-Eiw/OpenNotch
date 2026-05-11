import Foundation
import Combine

@MainActor
final class HUDSettingsStore: SettingsStoreBase {
    @Published var isBrightnessHUDEnabled: Bool {
        didSet {
            persist(isBrightnessHUDEnabled, for: GeneralSettingsStorage.Keys.brightnessHUDEnabled)
        }
    }

    @Published var brightnessHUDDuration: Int {
        didSet {
            let clampedValue = Self.clampTemporaryActivityDuration(brightnessHUDDuration)
            if clampedValue != brightnessHUDDuration {
                brightnessHUDDuration = clampedValue
                return
            }

            persist(brightnessHUDDuration, for: GeneralSettingsStorage.Keys.brightnessHUDDuration)
        }
    }

    @Published var isKeyboardHUDEnabled: Bool {
        didSet {
            persist(isKeyboardHUDEnabled, for: GeneralSettingsStorage.Keys.keyboardHUDEnabled)
        }
    }

    @Published var keyboardHUDDuration: Int {
        didSet {
            let clampedValue = Self.clampTemporaryActivityDuration(keyboardHUDDuration)
            if clampedValue != keyboardHUDDuration {
                keyboardHUDDuration = clampedValue
                return
            }

            persist(keyboardHUDDuration, for: GeneralSettingsStorage.Keys.keyboardHUDDuration)
        }
    }

    @Published var isVolumeHUDEnabled: Bool {
        didSet {
            persist(isVolumeHUDEnabled, for: GeneralSettingsStorage.Keys.volumeHUDEnabled)
        }
    }

    @Published var volumeHUDDuration: Int {
        didSet {
            let clampedValue = Self.clampTemporaryActivityDuration(volumeHUDDuration)
            if clampedValue != volumeHUDDuration {
                volumeHUDDuration = clampedValue
                return
            }

            persist(volumeHUDDuration, for: GeneralSettingsStorage.Keys.volumeHUDDuration)
        }
    }

    @Published var hudStyle: HudStyle {
        didSet {
            persist(hudStyle.rawValue, for: GeneralSettingsStorage.Keys.hudStyle)
        }
    }

    @Published var indicatorStyle: HudIndicatorStyle {
        didSet {
            persist(indicatorStyle.rawValue, for: GeneralSettingsStorage.Keys.hudIndicatorStyle)
        }
    }

    @Published var isColoredLevelEnabled: Bool {
        didSet {
            persist(isColoredLevelEnabled, for: GeneralSettingsStorage.Keys.hudColoredLevelEnabled)
        }
    }

    @Published var isColoredLevelStrokeEnabled: Bool {
        didSet {
            persist(isColoredLevelStrokeEnabled, for: GeneralSettingsStorage.Keys.hudColoredStrokeEnabled)
        }
    }

    override init(defaults: UserDefaults) {
        self.isBrightnessHUDEnabled = defaults.object(forKey: GeneralSettingsStorage.Keys.brightnessHUDEnabled) as? Bool ??
        (GeneralSettingsStorage.defaultValues[GeneralSettingsStorage.Keys.brightnessHUDEnabled] as? Bool ?? true)
        self.brightnessHUDDuration = Self.clampTemporaryActivityDuration(
            defaults.object(forKey: GeneralSettingsStorage.Keys.brightnessHUDDuration) as? Int ??
            Self.defaultTemporaryActivityDuration(for: GeneralSettingsStorage.Keys.brightnessHUDDuration)
        )
        self.isKeyboardHUDEnabled = defaults.object(forKey: GeneralSettingsStorage.Keys.keyboardHUDEnabled) as? Bool ??
        (GeneralSettingsStorage.defaultValues[GeneralSettingsStorage.Keys.keyboardHUDEnabled] as? Bool ?? true)
        self.keyboardHUDDuration = Self.clampTemporaryActivityDuration(
            defaults.object(forKey: GeneralSettingsStorage.Keys.keyboardHUDDuration) as? Int ??
            Self.defaultTemporaryActivityDuration(for: GeneralSettingsStorage.Keys.keyboardHUDDuration)
        )
        self.isVolumeHUDEnabled = defaults.object(forKey: GeneralSettingsStorage.Keys.volumeHUDEnabled) as? Bool ??
        (GeneralSettingsStorage.defaultValues[GeneralSettingsStorage.Keys.volumeHUDEnabled] as? Bool ?? true)
        self.volumeHUDDuration = Self.clampTemporaryActivityDuration(
            defaults.object(forKey: GeneralSettingsStorage.Keys.volumeHUDDuration) as? Int ??
            Self.defaultTemporaryActivityDuration(for: GeneralSettingsStorage.Keys.volumeHUDDuration)
        )
        self.hudStyle = HudStyle(
            rawValue: defaults.string(forKey: GeneralSettingsStorage.Keys.hudStyle) ?? HudStyle.compact.rawValue
        ) ?? .compact
        self.indicatorStyle = HudIndicatorStyle(
            rawValue: defaults.string(forKey: GeneralSettingsStorage.Keys.hudIndicatorStyle) ?? HudIndicatorStyle.bar.rawValue
        ) ?? .bar
        self.isColoredLevelEnabled = defaults.object(forKey: GeneralSettingsStorage.Keys.hudColoredLevelEnabled) as? Bool ??
        (GeneralSettingsStorage.defaultValues[GeneralSettingsStorage.Keys.hudColoredLevelEnabled] as? Bool ?? true)
        self.isColoredLevelStrokeEnabled = defaults.object(forKey: GeneralSettingsStorage.Keys.hudColoredStrokeEnabled) as? Bool ??
        (GeneralSettingsStorage.defaultValues[GeneralSettingsStorage.Keys.hudColoredStrokeEnabled] as? Bool ?? false)
        super.init(defaults: defaults)
    }

    func reset() {
        isBrightnessHUDEnabled = defaultBool(for: GeneralSettingsStorage.Keys.brightnessHUDEnabled)
        brightnessHUDDuration = Self.clampTemporaryActivityDuration(
            defaultInt(for: GeneralSettingsStorage.Keys.brightnessHUDDuration)
        )
        isKeyboardHUDEnabled = defaultBool(for: GeneralSettingsStorage.Keys.keyboardHUDEnabled)
        keyboardHUDDuration = Self.clampTemporaryActivityDuration(
            defaultInt(for: GeneralSettingsStorage.Keys.keyboardHUDDuration)
        )
        isVolumeHUDEnabled = defaultBool(for: GeneralSettingsStorage.Keys.volumeHUDEnabled)
        volumeHUDDuration = Self.clampTemporaryActivityDuration(
            defaultInt(for: GeneralSettingsStorage.Keys.volumeHUDDuration)
        )
        hudStyle = HudStyle(rawValue: defaultString(for: GeneralSettingsStorage.Keys.hudStyle)) ?? .compact
        indicatorStyle = HudIndicatorStyle(rawValue: defaultString(for: GeneralSettingsStorage.Keys.hudIndicatorStyle)) ?? .bar
        isColoredLevelEnabled = defaultBool(for: GeneralSettingsStorage.Keys.hudColoredLevelEnabled)
        isColoredLevelStrokeEnabled = defaultBool(for: GeneralSettingsStorage.Keys.hudColoredStrokeEnabled)
    }
}
