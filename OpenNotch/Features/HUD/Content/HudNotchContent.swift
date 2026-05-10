import SwiftUI

enum HudEvent: Equatable {
    case display(Int)
    case keyboard(Int)
    case volume(Int)
}

struct HudNotchContent: NotchContentProtocol {
    var id: String { kind.sharedContentID }
    var priority: Int { NotchContentPriority.default }

    let kind: HudPresentationKind
    let style: HudStyle
    let indicatorStyle: HudIndicatorStyle
    let level: Int
    let usesColoredLevelTint: Bool
    
    var strokeColor: Color { .white.opacity(0.2) }

    init(
        kind: HudPresentationKind,
        level: Int,
        style: HudStyle = .standard,
        indicatorStyle: HudIndicatorStyle = .bar,
        usesColoredLevelTint: Bool = true
    ) {
        self.kind = kind
        self.level = level
        self.style = style
        self.indicatorStyle = indicatorStyle
        self.usesColoredLevelTint = usesColoredLevelTint
    }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + widthOffset, height: baseHeight)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(
            HudContentView(
                image: kind.symbolName(for: level),
                text: kind.title,
                level: level,
                style: style,
                indicatorStyle: indicatorStyle,
                usesColoredLevelTint: usesColoredLevelTint
            )
        )
    }

    private var widthOffset: CGFloat {
        switch style {
        case .standard:
            switch indicatorStyle {
            case .bar:
                return kind == .keyboard ? 150 : 140
            case .circle:
                return 140
            }
        case .compact:
            switch indicatorStyle {
            case .bar:
                return 140
            case .circle:
                return 85
            }
        case .minimal:
            return 80
        }
    }

    private var resolvedColoredLevelStroke: Bool { false }
}
