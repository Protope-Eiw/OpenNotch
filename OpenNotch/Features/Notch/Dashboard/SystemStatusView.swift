import SwiftUI

struct SystemStatusView: View {
    @ObservedObject var systemMonitorViewModel: SystemMonitorViewModel
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    let macInfo: MacSystemInfo?

    var body: some View {
        HStack(spacing: 0) {
            SWRingChart(
                data: [
                    .init(label: "CPU", value: systemMonitorViewModel.cpuUsage, color: .green),
                    .init(label: "MEM", value: systemMonitorViewModel.memoryUsage, color: .orange),
                    .init(label: "DSK", value: systemMonitorViewModel.diskUsage, color: .cyan),
                ],
                maxValue: 100,
                size: 120,
                ringWidth: 10,
                spacing: 5,
                showLegend: false
            ) {
                VStack(spacing: 0) {
                    Text("CPU \(Int(systemMonitorViewModel.cpuUsage))%")
                        .foregroundStyle(.green)
                    Text("MEM \(Int(systemMonitorViewModel.memoryUsage))%")
                        .foregroundStyle(.orange)
                    Text("DSK \(Int(systemMonitorViewModel.diskUsage))%")
                        .foregroundStyle(.cyan)
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .frame(width: 120, height: 130)
            .padding(.leading, 16)

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 1)
                .padding(.vertical, 12)
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 8) {
                MacInfoCard(macInfo: macInfo)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    NetworkCard(
                        uploadSpeed: systemMonitorViewModel.formattedSpeed(systemMonitorViewModel.uploadSpeed),
                        downloadSpeed: systemMonitorViewModel.formattedSpeed(systemMonitorViewModel.downloadSpeed)
                    )
                    WifiCard(
                        connected: networkViewModel.wifiConnected,
                        name: networkViewModel.wifiName
                    )
                    BluetoothCard(
                        isOn: bluetoothViewModel.isBluetoothOn,
                        connected: bluetoothViewModel.isConnected,
                        deviceName: bluetoothViewModel.deviceName,
                        batteryLevel: bluetoothViewModel.batteryLevel,
                        deviceType: bluetoothViewModel.deviceType
                    )
                    BatteryCard(
                        level: systemMonitorViewModel.batteryLevel,
                        isCharging: systemMonitorViewModel.isCharging
                    )
                }

                DiskUsageCard(
                    usage: systemMonitorViewModel.diskUsage,
                    usedText: systemMonitorViewModel.diskUsedText,
                    totalText: systemMonitorViewModel.diskTotalText
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 1)
                .padding(.vertical, 12)

            BrightnessVolumeControls()
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mac Info

private struct MacInfoCard: View {
    let macInfo: MacSystemInfo?
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "macbook")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.3))

            VStack(alignment: .leading, spacing: 2) {
                Text(macInfo?.modelName ?? "Mac")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    infoBadge(macInfo?.chipName ?? "–")
                    infoBadge(macInfo?.ramText ?? "–")
                    infoBadge(macInfo?.macOSVersion ?? "–")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .scaleEffect(isPressed ? 0.97 : 1)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { isPressed = false }
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.systemprofiler")!)
        }
    }

    private func infoBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }
}

// MARK: - Connectivity Row Cards

private struct StatusCard<Icon: View, Content: View>: View {
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let content: () -> Content
    var action: (() -> Void)? = nil
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 8) {
            icon()
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .scaleEffect(isPressed ? 0.93 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            guard let action else { return }
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isPressed = false
                action()
            }
        }
    }
}

private func openSystemSettings(pane: String) {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:\(pane)")!)
}

private struct NetworkCard: View {
    let uploadSpeed: String
    let downloadSpeed: String

    var body: some View {
        StatusCard(
            icon: {
                Image(systemName: "network")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue.opacity(0.6))
            },
            content: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("↑")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange.opacity(0.7))
                        Text(uploadSpeed)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    HStack(spacing: 4) {
                        Text("↓")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.blue.opacity(0.7))
                        Text(downloadSpeed)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
            },
            action: { openSystemSettings(pane: "com.apple.Network") }
        )
    }
}

private struct WifiCard: View {
    let connected: Bool
    let name: String

    var body: some View {
        StatusCard(
            icon: {
                Image(systemName: connected ? "wifi" : "wifi.slash")
                    .font(.system(size: 16))
                    .foregroundStyle(connected ? .blue : .white.opacity(0.3))
            },
            content: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wi-Fi")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: 4) {
                        Circle()
                            .fill(connected ? Color.green : Color.white.opacity(0.2))
                            .frame(width: 5, height: 5)
                        Text(connected && !name.isEmpty ? name : "Off")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(connected ? .white : .white.opacity(0.35))
                            .lineLimit(1)
                    }
                }
            },
            action: { openSystemSettings(pane: "com.apple.wifi") }
        )
    }
}

private struct BluetoothCard: View {
    let isOn: Bool
    let connected: Bool
    let deviceName: String
    let batteryLevel: Int?
    var deviceType: BluetoothAudioDeviceType = .generic

    var body: some View {
        StatusCard(
            icon: {
                Image(systemName: connected ? deviceType.sfSymbol : isOn ? "bluetooth" : "bluetooth.slash")
                    .font(.system(size: 16))
                    .foregroundStyle(connected ? .blue : isOn ? .white.opacity(0.6) : .white.opacity(0.25))
            },
            content: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bluetooth")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: 4) {
                        Circle()
                            .fill(connected ? Color.green : isOn ? Color.blue.opacity(0.5) : Color.white.opacity(0.2))
                            .frame(width: 5, height: 5)
                        Text(connected ? deviceName : isOn ? "No devices" : "Off")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(connected || isOn ? .white : .white.opacity(0.35))
                            .lineLimit(1)
                    }
                }
            },
            action: { openSystemSettings(pane: "com.apple.Bluetooth") }
        )
    }
}

private struct BatteryCard: View {
    let level: Int
    let isCharging: Bool

    private var color: Color {
        level > 20 ? .green : .red
    }

    var body: some View {
        StatusCard(
            icon: {
                Image(systemName: batteryIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(color.opacity(0.7))
            },
            content: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(level)%")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    if isCharging {
                        Text("Charging")
                            .font(.system(size: 9))
                            .foregroundStyle(.green.opacity(0.7))
                    } else {
                        Text(" ")
                            .font(.system(size: 9))
                    }
                }
            },
            action: { openSystemSettings(pane: "com.apple.Battery") }
        )
    }

    private var batteryIcon: String {
        if isCharging { return "battery.100.bolt" }
        switch level {
        case 80...100: return "battery.100"
        case 60..<80:  return "battery.75"
        case 40..<60:  return "battery.50"
        case 20..<40:  return "battery.25"
        default:       return "battery.0"
        }
    }
}

// MARK: - Disk

private struct DiskUsageCard: View {
    let usage: Double
    let usedText: String
    let totalText: String
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "internaldrive")
                .font(.system(size: 16))
                .foregroundStyle(.cyan.opacity(0.6))

            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor)
                            .frame(width: geo.size.width * CGFloat(min(usage / 100, 1)), height: 4)
                    }
                }
                .frame(height: 4)

                HStack(spacing: 4) {
                    Text("\(usedText) / \(totalText)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\(Int(usage))%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(barColor.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .scaleEffect(isPressed ? 0.97 : 1)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { isPressed = false }
            NSWorkspace.shared.open(URL(string: "file:///")!)
        }
    }

    private var barColor: Color {
        usage > 90 ? .red : usage > 75 ? .orange : .cyan
    }
}

// MARK: - Brightness & Volume Controls

private struct BrightnessVolumeControls: View {
    @State private var brightness: Float = 0.7
    @State private var volume: Float = 0.5
    @State private var isMuted: Bool = false

    private let brightnessService = SystemDisplayBrightnessService()
    private let volumeService = SystemAudioVolumeService()

    var body: some View {
        HStack(spacing: 16) {
            VerticalLevelControl(
                icon: "sun.max.fill",
                level: $brightness,
                color: .orange,
                onChanged: { newValue in
                    brightnessService.setBrightness(newValue)
                }
            )

            VerticalLevelControl(
                icon: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                level: $volume,
                color: .blue,
                onChanged: { newValue in
                    volumeService.setVolume(newValue)
                    if newValue > 0.01 {
                        isMuted = false
                    } else {
                        isMuted = true
                    }
                },
                onIconTap: {
                    let result = volumeService.toggleMute()
                    isMuted = result == 0
                    if !isMuted {
                        volume = volumeService.currentVolume
                    } else {
                        volume = 0
                    }
                }
            )
        }
        .onAppear {
            brightness = brightnessService.currentBrightness
            volume = volumeService.currentVolume
            isMuted = volumeService.isMuted
        }
    }
}

private struct VerticalLevelControl: View {
    let icon: String
    @Binding var level: Float
    let color: Color
    let onChanged: (Float) -> Void
    var onIconTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 6) {
            Button(action: { onIconTap?() }) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color.opacity(0.7))
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                let trackHeight = geo.size.height
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 20)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.6))
                        .frame(width: 20, height: max(4, trackHeight * CGFloat(level)))
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newLevel = Float(max(0, min(1, 1 - value.location.y / trackHeight)))
                            level = newLevel
                            onChanged(newLevel)
                        }
                )
            }
            .frame(width: 20)

            Text("\(Int(level * 100))")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
