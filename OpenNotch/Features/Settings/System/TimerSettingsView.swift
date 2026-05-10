import SwiftUI

struct TimerSettingsView: View {
    @ObservedObject var mediaSettings: MediaAndFilesSettingsStore
    @ObservedObject var appearanceSettings: ApplicationSettingsStore

    private var isDefaultStrokeLocked: Bool {
        true
    }

    @ViewBuilder var cards: some View {
        timerActivity
    }

    var body: some View {
        SettingsPageScrollView { cards }
    }

    private var timerActivity: some View {
        SettingsCard(title: localized("Timer activity")) {
            SettingsToggleRow(
                title: localized("Timer live activity"),
                description: localized("Show the active Clock timer in the notch."),
                systemImage: "timer",
                color: .orange,
                isOn: $mediaSettings.isTimerLiveActivityEnabled,
                accessibilityIdentifier: "settings.activities.live.timer"
            )

            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

            SettingsStrokeToggleRow(
                title: localized("Default stroke"),
                description: localized("Use the standard white notch stroke instead of the orange timer stroke."),
                isOn: $mediaSettings.isTimerDefaultStrokeEnabled,
                accessibilityIdentifier: "settings.activities.live.timer.defaultStroke"
            )
            .disabled(isDefaultStrokeLocked)
            .opacity(isDefaultStrokeLocked ? 0.5 : 1)
        }
    }
    
    private func localized(_ key: String, fallback: String? = nil) -> String {
        appearanceSettings.appLanguage.locale.dn(key, fallback: fallback ?? key)
    }
}
