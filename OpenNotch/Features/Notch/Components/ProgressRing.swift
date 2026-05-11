import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let color: Color
    let label: String
    var valueText: String? = nil
    var showInternalText: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: min(progress / 100, 1))
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
            if showInternalText {
                VStack(spacing: 1) {
                    Text(valueText ?? "\(Int(progress))")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    if !label.isEmpty {
                        Text(label)
                            .font(.system(size: 6, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
    }
}
