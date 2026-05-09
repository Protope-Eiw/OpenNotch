import SwiftUI

enum VPNAppearanceStyle: String, CaseIterable {
    case compact
    case detailed

    var title: String {
        switch self {
        case .compact:
            return "Compact"
        case .detailed:
            return "Detailed"
        }
    }
}
