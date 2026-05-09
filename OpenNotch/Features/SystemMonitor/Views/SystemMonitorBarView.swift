import SwiftUI

struct SystemMonitorBarView: View {
    @ObservedObject var viewModel: SystemMonitorViewModel
    let notchWidth: CGFloat
    let notchHeight: CGFloat

    private let pillExtension: CGFloat = 140
    private let cornerRadius: CGFloat = 9

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let leftEdge  = cx - notchWidth / 2
            let rightEdge = cx + notchWidth / 2

            ZStack(alignment: .topLeading) {
                // 左侧药丸：网速
                leftPill
                    .frame(width: pillExtension, height: notchHeight)
                    .position(x: leftEdge - pillExtension / 2, y: notchHeight / 2)

                // 右侧药丸：CPU + 内存
                rightPill
                    .frame(width: pillExtension, height: notchHeight)
                    .position(x: rightEdge + pillExtension / 2, y: notchHeight / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var leftPill: some View {
        HStack(spacing: 5) {
            Spacer(minLength: 0)
            Text("↑\(viewModel.formattedSpeed(viewModel.uploadSpeed))")
            Text("↓\(viewModel.formattedSpeed(viewModel.downloadSpeed))")
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius,
                bottomLeadingRadius: cornerRadius,
                bottomTrailingRadius: 3,
                topTrailingRadius: 3
            )
        )
    }

    private var rightPill: some View {
        HStack(spacing: 5) {
            Text("CPU \(Int(viewModel.cpuUsage))%")
                .foregroundStyle(Color.thresholdColor(viewModel.cpuUsage, warn: 50, danger: 80))
            Text("MEM \(Int(viewModel.memoryUsage))%")
                .foregroundStyle(Color.thresholdColor(viewModel.memoryUsage, warn: 70, danger: 85))
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 3,
                bottomLeadingRadius: 3,
                bottomTrailingRadius: cornerRadius,
                topTrailingRadius: cornerRadius
            )
        )
    }

}
