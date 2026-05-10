import SwiftUI

struct NetworkSettingsView: View {
    @ObservedObject var connectivitySettings: ConnectivitySettingsStore
    @ObservedObject var appearanceSettings: ApplicationSettingsStore
    
    private var temporaryActivityDurationRange: ClosedRange<Double> {
        Double(SettingsStoreBase.temporaryActivityDurationRange.lowerBound)...Double(SettingsStoreBase.temporaryActivityDurationRange.upperBound)
    }
    
    private var vpnAppearanceStyle: Binding<VPNAppearanceStyle> {
        Binding(
            get: { connectivitySettings.isVPNDetailVisible ? .detailed : .compact },
            set: { connectivitySettings.isVPNDetailVisible = $0 == .detailed }
        )
    }
    
    private var isDetailedVPNStyle: Bool {
        vpnAppearanceStyle.wrappedValue == .detailed
    }

    private var isHotspotDefaultStrokeLocked: Bool {
        true
    }

    private var hotspotPreviewStrokeColor: Color {
        return .clear
    }

    private var vpnPreviewStrokeColor: Color {
        .clear
    }
    
    @ViewBuilder var cards: some View {
        networkActivity
        networkDuration
        vpnAppearance
        hotspotAppearance
    }

    var body: some View {
        SettingsPageScrollView { cards }
    }
    
    private var networkActivity: some View {
        SettingsCard(title: localized("Network activity")) {
            SettingsToggleRow(
                title: localized("Wi-Fi temporary activity"),
                description: localized("Show a short notification when Wi-Fi reconnects."),
                systemImage: "wifi",
                color: .blue,
                isOn: $connectivitySettings.isWifiTemporaryActivityEnabled,
                accessibilityIdentifier: "settings.activities.temporary.wifi"
            )
            
            Divider()
                .opacity(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: localized("VPN temporary activity"),
                description: localized("Show a short notification when a VPN connection becomes active."),
                systemImage: "network",
                color: .blue,
                isOn: $connectivitySettings.isVpnTemporaryActivityEnabled,
                accessibilityIdentifier: "settings.activities.temporary.vpn"
            )
            
            Divider()
                .opacity(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

            SettingsToggleRow(
                title: localized("No internet temporary activity"),
                description: localized("Show a short notification when your Mac loses internet access."),
                systemImage: "wifi.slash",
                color: .red,
                isOn: $connectivitySettings.isNoInternetTemporaryActivityEnabled,
                accessibilityIdentifier: "settings.activities.temporary.noInternet"
            )

            Divider()
                .opacity(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: localized("Personal Hotspot live activity"),
                description: localized("Show a live activity while Personal Hotspot is enabled."),
                systemImage: "personalhotspot",
                color: .green,
                isOn: $connectivitySettings.isHotspotLiveActivityEnabled,
                accessibilityIdentifier: "settings.activities.live.hotspot"
            )
        }
    }
    
    private var networkDuration: some View {
        SettingsCard(title: localized("Network duration")) {
            SettingsSliderRow(
                title: localized("Wi-Fi duration"),
                description: localized("Choose how long the Wi-Fi reconnect notification stays visible."),
                range: temporaryActivityDurationRange,
                step: 1,
                fractionLength: 0,
                suffix: "s",
                accessibilityIdentifier: "settings.activities.temporary.wifi.duration",
                value: Binding(
                    get: { Double(connectivitySettings.wifiTemporaryActivityDuration) },
                    set: { connectivitySettings.wifiTemporaryActivityDuration = Int($0.rounded()) }
                )
            )
            .disabled(!connectivitySettings.isWifiTemporaryActivityEnabled)
            .opacity(connectivitySettings.isWifiTemporaryActivityEnabled ? 1 : 0.5)
            
            SettingsDivider()
            
            SettingsSliderRow(
                title: localized("VPN duration"),
                description: localized("Choose how long the VPN connection notification stays visible."),
                range: temporaryActivityDurationRange,
                step: 1,
                fractionLength: 0,
                suffix: "s",
                accessibilityIdentifier: "settings.activities.temporary.vpn.duration",
                value: Binding(
                    get: { Double(connectivitySettings.vpnTemporaryActivityDuration) },
                    set: { connectivitySettings.vpnTemporaryActivityDuration = Int($0.rounded()) }
                )
            )
            .disabled(!connectivitySettings.isVpnTemporaryActivityEnabled)
            .opacity(connectivitySettings.isVpnTemporaryActivityEnabled ? 1 : 0.5)
        }
    }
    
    private var vpnAppearance: some View {
        SettingsCard(title: localized("VPN appearance")) {
            CustomPicker(
                selection: vpnAppearanceStyle,
                options: Array(VPNAppearanceStyle.allCases),
                title: { localized($0.title) },
                headerTitle: localized("VPN style"),
                headerDescription: localized("Choose whether the VPN activity stays compact or shows tunnel details."),
                itemHeight: 72,
                lightBackgroundImage: Image("backgroundLight"),
                darkBackgroundImage: Image("backgroundDark")
            ) { style, isSelected in
                vpnAppearancePickerContent(for: style, isSelected: isSelected, isTimerVisible: connectivitySettings.isVPNTimerVisible)
            }
            .accessibilityIdentifier("settings.activities.temporary.vpn.style")
            
            Divider()
                .opacity(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: localized("Only notify on network change"),
                description: localized("Only show Wi-Fi or VPN notifications when the connected network actually changes."),
                systemImage: "point.3.connected.trianglepath.dotted",
                color: .red,
                isOn: $connectivitySettings.isOnlyNotifyOnNetworkChangeEnabled,
                accessibilityIdentifier: "settings.activities.temporary.network.changeOnly"
            )
        }
    }
    
    private var hotspotAppearance: some View {
        SettingsCard(title: localized("Hotspot appearance")) {
            CustomPicker(
                selection: $connectivitySettings.hotspotAppearanceStyle,
                options: Array(HotspotAppearanceStyle.allCases),
                title: { localized($0.title) },
                headerTitle: localized("Appearance"),
                headerDescription: localized("Choose whether the hotspot activity stays minimal or shows more status."),
                itemHeight: 72,
                lightBackgroundImage: Image("backgroundLight"),
                darkBackgroundImage: Image("backgroundDark")
            ) { style, isSelected in
                hotspotAppearancePickerContent(for: style, isSelected: isSelected)
            }

            SettingsDivider()

            SettingsStrokeToggleRow(
                title: localized("Default stroke"),
                description: localized("Use the standard white notch stroke instead of the hotspot accent stroke."),
                isOn: $connectivitySettings.isHotspotDefaultStrokeEnabled,
                accessibilityIdentifier: "settings.activities.live.hotspot.defaultStroke"
            )
            .disabled(isHotspotDefaultStrokeLocked)
            .opacity(isHotspotDefaultStrokeLocked ? 0.5 : 1)
        }
    }
    
    @ViewBuilder
    private func vpnAppearancePickerContent(for style: VPNAppearanceStyle, isSelected: Bool, isTimerVisible: Bool) -> some View {
        switch style {
        case .compact:
            ZStack {
                Capsule()
                    .fill(.black)
                    .overlay {
                        Capsule()
                            .stroke(vpnPreviewStrokeColor, lineWidth: 1)
                    }
                HStack {
                    ZStack {
                        Capsule()
                            .fill(Color.accentColor.gradient)
                            .frame(width: 40, height: 20)
                        
                        Image(systemName: "network.badge.shield.half.filled")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.gradient)
                    }
                    
                    Spacer()
                    
                    Text(verbatim: "Active")
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .padding(.leading, 5)
                .padding(.trailing, 10)
            }
            .frame(width: 200, height: 30)
            .scaleEffect(isSelected ? 1 : 0.97)
            
        case .detailed:
            ZStack {
                Capsule()
                    .fill(.black)
                    .overlay {
                        Capsule()
                            .stroke(vpnPreviewStrokeColor, lineWidth: 1)
                    }
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "network.badge.shield.half.filled")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.8))
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: "Connected")
                                .lineLimit(1)
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.4))
                            
                            Text(localized("WireGuard VPN"))
                                .lineLimit(1)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                
                    Text(localized("00:10"))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 12)
            }
            .frame(width: 210, height: 50)
            .scaleEffect(isSelected ? 1 : 0.97)
        }
    }
    
    @ViewBuilder
    private func hotspotAppearancePickerContent(for style: HotspotAppearanceStyle, isSelected: Bool) -> some View {
        switch style {
        case .minimal:
            ZStack {
                Capsule()
                    .fill(.black)
                    .overlay {
                        Capsule()
                            .stroke(hotspotPreviewStrokeColor, lineWidth: 1)
                    }
                
                HStack {
                    Image(systemName: "personalhotspot")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.green)
                    
                    Spacer()
                }
                .padding(.horizontal, 7)
            }
            .frame(width: 160, height: 30)
            .scaleEffect(isSelected ? 1 : 0.97)
            
        case .detailed:
            ZStack {
                Capsule()
                    .fill(.black)
                    .overlay {
                        Capsule()
                            .stroke(hotspotPreviewStrokeColor, lineWidth: 1)
                    }
                
                HStack(spacing: 10) {
                    Image(systemName: "personalhotspot")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.green)
                    
                    Spacer()
                    
                    Text(verbatim: "On")
                        .foregroundStyle(.green.opacity(0.8))
                }
                .padding(.leading, 7)
                .padding(.trailing, 10)
            }
            .frame(width: 160, height: 30)
            .scaleEffect(isSelected ? 1 : 0.97)
        }
    }
    
    private func localized(_ key: String, fallback: String? = nil) -> String {
        appearanceSettings.appLanguage.locale.dn(key, fallback: fallback ?? key)
    }
}
