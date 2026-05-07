import SwiftUI

private struct SettingsSectionDescriptor {
    let titleKey: String
    let fallbackTitle: String
    let subtitleKey: String
    let fallbackSubtitle: String
    let searchKeywords: [String]
    let systemImage: String
    let imageName: String?
    let tint: Color
    let resetGroup: SettingsViewModel.ResetGroup?
}

extension SettingsRootViewModel {
    enum Section: String, CaseIterable, Identifiable {
        case general
        case permissions
        case notch
        case interface
        case media
        case connectivity
        case system
        case lockScreen
        case donation
        #if DEBUG
        case debug
        #endif

        var id: String { rawValue }

        var titleKey: String { descriptor.titleKey }
        var fallbackTitle: String { descriptor.fallbackTitle }
        var subtitleKey: String { descriptor.subtitleKey }
        var fallbackSubtitle: String { descriptor.fallbackSubtitle }
        var searchKeywords: [String] { descriptor.searchKeywords }
        var systemImage: String { descriptor.systemImage }
        var imageName: String? { descriptor.imageName }
        var tint: Color { descriptor.tint }
        var resetGroup: SettingsViewModel.ResetGroup? { descriptor.resetGroup }
        var accessibilityIdentifier: String { "settings.tab.\(rawValue)" }

        func localizedTitle(locale: Locale) -> String {
            locale.dn(titleKey, fallback: fallbackTitle)
        }

        static func initialSelection(storedValue: String?) -> Self {
            switch storedValue ?? "" {
            case "language":
                return .general
            case "permissions":
                return .permissions
            case "activities", "liveActivity", "nowPlaying", "downloads", "drop", "airDrop", "dragAndDrop":
                return .media
            case "hotspot", "wifi", "vpn", "bluetooth", "focus", "network":
                return .connectivity
            case "temporaryActivity", "battery", "hud", "timer", "screenRecording":
                return .system
            default:
                return Self(rawValue: storedValue ?? "") ?? .general
            }
        }

        private var descriptor: SettingsSectionDescriptor {
            SettingsSectionCatalog.sectionDescriptor(for: self)
        }
    }
}

private enum SettingsSectionCatalog {
    static func sectionDescriptor(
        for section: SettingsRootViewModel.Section
    ) -> SettingsSectionDescriptor {
        switch section {
        case .general:
            return .init(
                titleKey: "settings.section.general.title",
                fallbackTitle: "General",
                subtitleKey: "settings.section.general.subtitle",
                fallbackSubtitle: "Startup, display placement, and app language.",
                searchKeywords: [
                    "launch at login", "dock icon", "menu bar",
                    "appearance", "language", "display", "fullscreen"
                ],
                systemImage: "gear",
                imageName: nil,
                tint: .blue,
                resetGroup: .general
            )

        case .permissions:
            return .init(
                titleKey: "settings.section.permissions.title",
                fallbackTitle: "Permissions",
                subtitleKey: "settings.section.permissions.subtitle",
                fallbackSubtitle: "Accessibility, Bluetooth, and media control access.",
                searchKeywords: [
                    "permissions", "accessibility", "bluetooth",
                    "media controls", "grant access"
                ],
                systemImage: "checkmark.seal.fill",
                imageName: nil,
                tint: .green,
                resetGroup: nil
            )

        case .notch:
            return .init(
                titleKey: "settings.section.notch.title",
                fallbackTitle: "Notch",
                subtitleKey: "settings.section.notch.subtitle",
                fallbackSubtitle: "Appearance, animation, and resize feedback.",
                searchKeywords: [
                    "background", "stroke", "animation", "speed",
                    "resize", "width", "height"
                ],
                systemImage: "rectangle.topthird.inset.filled",
                imageName: nil,
                tint: .gray,
                resetGroup: .notch
            )

        case .interface:
            return .init(
                titleKey: "settings.section.interface.title",
                fallbackTitle: "界面",
                subtitleKey: "settings.section.interface.subtitle",
                fallbackSubtitle: "Dashboard layout, app grid, and overview customization.",
                searchKeywords: [
                    "overview", "app grid", "app names", "time",
                    "date", "weather", "system info", "pomodoro", "timer"
                ],
                systemImage: "rectangle.split.3x1.fill",
                imageName: nil,
                tint: .teal,
                resetGroup: nil
            )

        case .media:
            return .init(
                titleKey: "settings.section.media.title",
                fallbackTitle: "Media",
                subtitleKey: "settings.section.media.subtitle",
                fallbackSubtitle: "Now Playing, Downloads, and Drag&Drop activities.",
                searchKeywords: [
                    "now playing", "music", "downloads",
                    "drag and drop", "airdrop", "tray", "player"
                ],
                systemImage: "play.circle.fill",
                imageName: nil,
                tint: .red,
                resetGroup: nil
            )

        case .connectivity:
            return .init(
                titleKey: "settings.section.connectivity.title",
                fallbackTitle: "Connectivity",
                subtitleKey: "settings.section.connectivity.subtitle",
                fallbackSubtitle: "Bluetooth, Wi-Fi, VPN, Hotspot, and Focus activities.",
                searchKeywords: [
                    "bluetooth", "wifi", "vpn", "hotspot",
                    "focus", "network", "internet"
                ],
                systemImage: "antenna.radiowaves.left.and.right",
                imageName: nil,
                tint: .blue,
                resetGroup: nil
            )

        case .system:
            return .init(
                titleKey: "settings.section.system.title",
                fallbackTitle: "System",
                subtitleKey: "settings.section.system.subtitle",
                fallbackSubtitle: "Battery alerts, HUD overlays, Timer, and Screen Recording.",
                searchKeywords: [
                    "battery", "charging", "brightness", "volume",
                    "keyboard", "hud", "timer", "screen recording"
                ],
                systemImage: "cpu.fill",
                imageName: nil,
                tint: .orange,
                resetGroup: nil
            )

        case .lockScreen:
            return .init(
                titleKey: "settings.section.lockScreen.title",
                fallbackTitle: "Lock Screen",
                subtitleKey: "settings.section.lockScreen.subtitle",
                fallbackSubtitle: "Lock transitions, sound, and lock-screen media behavior.",
                searchKeywords: [
                    "lock sound", "unlock sound", "media panel",
                    "widget appearance", "background brightness", "accent tint"
                ],
                systemImage: "lock.fill",
                imageName: nil,
                tint: .gray,
                resetGroup: .lockScreen
            )

        case .donation:
            return .init(
                titleKey: "settings.section.donation.title",
                fallbackTitle: "支持 OpenNotch",
                subtitleKey: "settings.section.donation.subtitle",
                fallbackSubtitle: "",
                searchKeywords: ["donate", "support", "coffee", "wechat", "微信", "捐赠"],
                systemImage: "heart.fill",
                imageName: nil,
                tint: .pink,
                resetGroup: nil
            )

        #if DEBUG
        case .debug:
            return .init(
                titleKey: "settings.section.debug.title",
                fallbackTitle: "Debug",
                subtitleKey: "settings.section.debug.subtitle",
                fallbackSubtitle: "Manual previews and event triggers for testing.",
                searchKeywords: ["preview", "trigger", "debug"],
                systemImage: "ladybug",
                imageName: nil,
                tint: .red,
                resetGroup: nil
            )
        #endif
        }
    }
}
