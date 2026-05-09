import SwiftUI

enum LockScreenStyle: String, CaseIterable {
    case enlarged
    case compact

    var title: String {
        switch self {
        case .enlarged:
            return "Enlarged"
        case .compact:
            return "Compact"
        }
    }
}
