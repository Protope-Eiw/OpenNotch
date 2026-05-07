import SwiftUI

struct ConnectivitySettingsView: View {
    @ObservedObject var connectivitySettings: ConnectivitySettingsStore
    @ObservedObject var applicationSettings: ApplicationSettingsStore

    var body: some View {
        SettingsPageScrollView {
            BluetoothSettingsView(
                settings: connectivitySettings,
                applicationSettings: applicationSettings
            ).cards

            NetworkSettingsView(
                connectivitySettings: connectivitySettings,
                appearanceSettings: applicationSettings
            ).cards

            FocusSettingsView(
                connectivitySettings: connectivitySettings,
                appearanceSettings: applicationSettings
            ).cards
        }
    }
}
