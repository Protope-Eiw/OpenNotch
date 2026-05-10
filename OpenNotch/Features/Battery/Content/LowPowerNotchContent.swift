import SwiftUI

struct LowPowerNotchContent: NotchContentProtocol {
    let id = NotchContentRegistry.Power.lowPower.id
    var priority: Int { NotchContentRegistry.Power.lowPower.priority }
    
    let powerService: PowerService
    let settingsViewModel: SettingsViewModel

    private var style: BatteryNotificationStyle {
        settingsViewModel.battery.lowPowerStyle
    }

    var strokeColor: Color { .white.opacity(0.2) }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        if style == .compact {
            return .init(width: baseWidth + 180, height: baseHeight)
        }

        return .init(width: baseWidth + 100, height: baseHeight + 75)
    }

    func cornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        if style == .compact {
            return (top: baseRadius - 4, bottom: baseRadius)
        }

        return (top: 22, bottom: 40)
    }

    @MainActor
    func makeView() -> AnyView {
        AnyView(
            LowPowerNotchView(
                powerService: powerService,
                style: style
            )
        )
    }
}
