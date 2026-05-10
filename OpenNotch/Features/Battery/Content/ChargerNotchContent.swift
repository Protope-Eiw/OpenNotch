import SwiftUI

enum PowerEvent: Equatable {
    case charger
    case lowPower
    case fullPower
}

struct ChargerNotchContent: NotchContentProtocol {
    let id = NotchContentRegistry.Power.charger.id
    var priority: Int { NotchContentRegistry.Power.charger.priority }
    
    let powerService: PowerService
    let settingsViewModel: SettingsViewModel
    
    var strokeColor: Color { .white.opacity(0.2) }
    
    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        return .init(width: baseWidth + 180, height: baseHeight)
    }
    
    @MainActor
    func makeView() -> AnyView {
        AnyView(ChargerNotchView(powerService: powerService))
    }
}
