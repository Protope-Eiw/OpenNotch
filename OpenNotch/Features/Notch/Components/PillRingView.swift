import SwiftUI

struct PillRingView: View {
    @ObservedObject var systemMonitorViewModel: SystemMonitorViewModel
    let widget: NotchBarWidget
    let ringSize: CGFloat

    @AppStorage(AppStorageKeys.NotchBar.networkSpeedColorMode) private var networkSpeedColorModeRaw = NetworkSpeedColorMode.directional.rawValue

    var body: some View {
        switch widget {
        case .networkSpeed:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(networkSpeedColor.upload)
                    Text(systemMonitorViewModel.formattedSpeed(systemMonitorViewModel.uploadSpeed))
                        .foregroundStyle(networkSpeedColor.upload)
                }
                HStack(spacing: 3) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(networkSpeedColor.download)
                    Text(systemMonitorViewModel.formattedSpeed(systemMonitorViewModel.downloadSpeed))
                        .foregroundStyle(networkSpeedColor.download)
                }
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
        case .cpu:
            ProgressRing(progress: systemMonitorViewModel.cpuUsage,
                         color: Color.pillColor(systemMonitorViewModel.cpuUsage, warn: 50, danger: 80),
                         label: "CPU")
                .frame(width: ringSize, height: ringSize)
        case .memory:
            ProgressRing(progress: systemMonitorViewModel.memoryUsage,
                         color: Color.pillColor(systemMonitorViewModel.memoryUsage, warn: 70, danger: 85),
                         label: "MEM")
                .frame(width: ringSize, height: ringSize)
        case .disk:
            ProgressRing(progress: systemMonitorViewModel.diskUsage,
                         color: Color.pillColor(systemMonitorViewModel.diskUsage, warn: 80, danger: 90),
                         label: "DSK")
                .frame(width: ringSize, height: ringSize)
        }
    }

    private var networkSpeedColor: (upload: Color, download: Color) {
        switch NetworkSpeedColorMode(rawValue: networkSpeedColorModeRaw) ?? .directional {
        case .directional:
            return (.blue, .green)
        case .unifiedWhite:
            return (.white, .white)
        }
    }
}
