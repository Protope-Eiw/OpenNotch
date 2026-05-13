import SwiftUI

struct SWKPICard<Trailing: View>: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        value: String,
        icon: String,
        tint: Color,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.tint = tint
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(tint)
                .contentTransition(.numericText())

            trailing()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }
}

extension SWKPICard where Trailing == EmptyView {
    init(
        title: String,
        value: String,
        icon: String,
        tint: Color
    ) {
        self.init(title: title, value: value, icon: icon, tint: tint) {
            EmptyView()
        }
    }
}

struct SWKPIDeltaTag: View {
    let delta: Double?
    var comparisonLabel: String = "vs yesterday"
    var upColor: Color = .green
    var downColor: Color = .red
    var emptyLabel: String = "No data"

    var body: some View {
        if let delta {
            let isUp = delta >= 0
            HStack(spacing: 4) {
                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                Text("\(isUp ? "+" : "")\(delta, specifier: "%.1f")% \(comparisonLabel)")
            }
            .font(.caption2)
            .foregroundStyle(isUp ? upColor : downColor)
        } else {
            Text(emptyLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
