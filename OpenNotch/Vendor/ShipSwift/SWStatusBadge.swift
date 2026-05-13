import SwiftUI

enum SWStatusBadgeStyle: CaseIterable {
    case info
    case success
    case warning
    case error
    case neutral

    var tint: Color {
        switch self {
        case .info:    .blue
        case .success: .green
        case .warning: .orange
        case .error:   .red
        case .neutral: .white.opacity(0.5)
        }
    }

    var backgroundOpacity: Double {
        switch self {
        case .success: 0.20
        default:       0.18
        }
    }
}

struct SWStatusBadge: View {
    let text: String
    let style: SWStatusBadgeStyle

    init(text: String, style: SWStatusBadgeStyle) {
        self.text = text
        self.style = style
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(style.tint)
            .background(
                Capsule().fill(style.tint.opacity(style.backgroundOpacity))
            )
            .overlay(
                Capsule().stroke(style.tint.opacity(0.35), lineWidth: 0.5)
            )
    }
}
