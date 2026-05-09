import SwiftUI

extension Color {
    static func thresholdColor(_ value: Double, warn: Double, danger: Double) -> Color {
        value >= danger ? .red : value >= warn ? .orange : .green.opacity(0.9)
    }

    static func batteryColor(_ level: Int, isCharging: Bool) -> Color {
        if isCharging { return .green }
        if level <= 20 { return .red }
        if level <= 40 { return .orange }
        return .green.opacity(0.9)
    }

    static func netSpeedColor(_ bps: Double) -> Color {
        switch bps {
        case ..<50_000:     return .cyan
        case ..<500_000:    return .mint
        case ..<2_000_000:  return .green
        case ..<10_000_000: return .yellow
        case ..<50_000_000: return .orange
        default:            return .red
        }
    }

    static func pillColor(_ value: Double, warn: Double, danger: Double) -> Color {
        value >= danger ? .red : value >= warn ? .orange : .green.opacity(0.9)
    }
}
