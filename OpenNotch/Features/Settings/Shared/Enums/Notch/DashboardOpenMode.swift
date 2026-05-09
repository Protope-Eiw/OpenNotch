import SwiftUI

enum DashboardOpenMode: String, CaseIterable {
    case hover
    case click

    var title: String {
        switch self {
        case .hover: return "Hover"
        case .click: return "Click"
        }
    }

    static func resolved(_ rawValue: String?) -> DashboardOpenMode {
        guard let rawValue, let mode = DashboardOpenMode(rawValue: rawValue) else {
            return .hover
        }
        return mode
    }
}
