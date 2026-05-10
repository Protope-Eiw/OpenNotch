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

    var settingsDescription: LocalizedStringKey {
        switch self {
        case .overview: return "Quick overview with pinned apps, time, and system info."
        case .music:    return "Music player with playback controls and progress bar."
        case .system:   return "CPU, memory, disk, network, and battery stats."
        case .calendar: return "Today's calendar events from your calendars."
        case .apps:     return "Quick launcher for pinned apps."
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
