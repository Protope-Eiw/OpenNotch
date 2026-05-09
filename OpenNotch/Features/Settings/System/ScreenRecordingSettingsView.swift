import SwiftUI

struct ScreenRecordingSettingsView: View {
    @ObservedObject var settings: ScreenRecordingSettingsStore
    @ObservedObject var appearanceSettings: ApplicationSettingsStore

    private var isDefaultStrokeLocked: Bool {
        appearanceSettings.isDefaultActivityStrokeEnabled
    }

    @ViewBuilder var cards: some View {
        screenRecordingActivity
    }

    var body: some View {
        SettingsPageScrollView { cards }
    }

    private var screenRecordingActivity: some View {
        SettingsCard(title: localized("Screen Recording activity")) {
            SettingsToggleRow(
                title: localized("Screen Recording live activity"),
                description: localized("Show a red recording indicator in the notch while screen capture is active."),
                systemImage: "record.circle.fill",
                color: .red,
                isOn: $settings.isScreenRecordingLiveActivityEnabled,
                accessibilityIdentifier: "settings.activities.live.screenRecording"
            )

            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

            SettingsStrokeToggleRow(
                title: localized("Default stroke"),
                description: localized("Use the standard white notch stroke instead of the red recording stroke."),
                isOn: $settings.isScreenRecordingDefaultStrokeEnabled,
                accessibilityIdentifier: "settings.activities.live.screenRecording.defaultStroke"
            )
            .disabled(isDefaultStrokeLocked)
            .opacity(isDefaultStrokeLocked ? 0.5 : 1)
        }
    }
    
    private func localized(_ key: String, fallback: String? = nil) -> String {
        appearanceSettings.appLanguage.locale.dn(key, fallback: fallback ?? key)
    }
}
