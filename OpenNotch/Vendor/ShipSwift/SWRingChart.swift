import SwiftUI

struct SWRingChart<Center: View>: View {
    struct DataPoint: Identifiable {
        var id: String { label }
        let label: String
        let value: Double
        let color: Color
    }

    let data: [DataPoint]
    var maxValue: Double = 100
    var size: CGFloat = 250
    var ringWidth: CGFloat = 25
    var spacing: CGFloat = 10
    var showLegend: Bool = true
    @ViewBuilder let center: () -> Center

    @State private var ready = false

    init(
        data: [DataPoint],
        maxValue: Double = 100,
        size: CGFloat = 250,
        ringWidth: CGFloat = 25,
        spacing: CGFloat = 10,
        showLegend: Bool = true,
        @ViewBuilder center: @escaping () -> Center
    ) {
        self.data = data
        self.maxValue = maxValue
        self.size = size
        self.ringWidth = ringWidth
        self.spacing = spacing
        self.showLegend = showLegend
        self.center = center
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    let ringIndex = CGFloat(data.count - 1 - index)
                    let ringSize = size - ringIndex * (ringWidth + spacing) * 2
                    let progress = maxValue > 0 && ready ? min(item.value / maxValue, 1) : 0

                    Circle()
                        .stroke(
                            item.color.opacity(0.15),
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                        )
                        .frame(width: ringSize, height: ringSize)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            item.color,
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringSize, height: ringSize)
                }

                center()
            }

            if showLegend {
                HStack(spacing: 16) {
                    ForEach(data) { item in
                        HStack(spacing: 4) {
                            Capsule()
                                .fill(item.color)
                                .frame(width: 3, height: 8)
                            Text(item.label)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                            Text("\(Int(item.value))")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
                ready = true
            }
        }
    }
}

extension SWRingChart where Center == EmptyView {
    init(
        data: [DataPoint],
        maxValue: Double = 100,
        size: CGFloat = 250,
        ringWidth: CGFloat = 25,
        spacing: CGFloat = 10,
        showLegend: Bool = true
    ) {
        self.init(data: data, maxValue: maxValue, size: size, ringWidth: ringWidth, spacing: spacing, showLegend: showLegend) {
            EmptyView()
        }
    }
}
