import SwiftUI

enum DashboardTab: String, CaseIterable {
    case overview = "overview"
    case music    = "Music"
    case system   = "System"
    case calendar = "Calendar"
    case apps     = "Apps"

    var icon: String {
        switch self {
        case .overview: return "house.fill"
        case .music:    return "music.note"
        case .system:   return "cpu"
        case .calendar: return "calendar"
        case .apps:     return "square.grid.2x2"
        }
    }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .music:    return "Music"
        case .system:   return "System Status"
        case .calendar: return "Calendar"
        case .apps:     return "App Launcher"
        }
    }

    var titleKey: String {
        switch self {
        case .overview: return "settings.interface.tab.overview"
        case .music:    return "settings.interface.tab.music"
        case .system:   return "settings.interface.tab.system"
        case .calendar: return "settings.interface.tab.calendar"
        case .apps:     return "settings.interface.tab.apps"
        }
    }

    var settingsColor: Color {
        switch self {
        case .overview: return .teal
        case .music:    return .pink
        case .system:   return .blue
        case .calendar: return .orange
        case .apps:     return .purple
        }
    }
}
