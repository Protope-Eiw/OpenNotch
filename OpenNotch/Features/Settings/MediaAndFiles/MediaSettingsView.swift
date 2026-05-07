import SwiftUI

struct MediaSettingsView: View {
    @ObservedObject var mediaSettings: MediaAndFilesSettingsStore
    @ObservedObject var applicationSettings: ApplicationSettingsStore

    var body: some View {
        SettingsPageScrollView {
            NowPlayingSettingsView(
                settings: mediaSettings,
                applicationSettings: applicationSettings
            ).cards

            DownloadsSettingsView(
                mediaSettings: mediaSettings,
                appearanceSettings: applicationSettings
            ).cards

            DropSettingsView(
                mediaSettings: mediaSettings,
                appearanceSettings: applicationSettings
            ).cards
        }
    }
}
