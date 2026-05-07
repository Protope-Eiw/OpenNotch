import SwiftUI

struct SystemSettingsView: View {
    @ObservedObject var batterySettings: BatterySettingsStore
    @ObservedObject var hudSettings: HUDSettingsStore
    @ObservedObject var mediaSettings: MediaAndFilesSettingsStore
    @ObservedObject var screenRecordingSettings: ScreenRecordingSettingsStore
    @ObservedObject var applicationSettings: ApplicationSettingsStore

    var body: some View {
        SettingsPageScrollView {
            BatterySettingsView(
                batterySettings: batterySettings,
                appearanceSettings: applicationSettings
            ).cards

            HUDSettingsView(
                settings: hudSettings,
                applicationSettings: applicationSettings
            ).cards

            TimerSettingsView(
                mediaSettings: mediaSettings,
                appearanceSettings: applicationSettings
            ).cards

            ScreenRecordingSettingsView(
                settings: screenRecordingSettings,
                appearanceSettings: applicationSettings
            ).cards
        }
    }
}
