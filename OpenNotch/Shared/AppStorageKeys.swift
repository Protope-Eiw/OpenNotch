import Foundation

enum AppStorageKeys {
    enum General {
        static let dashboardLastTab         = "settings.general.dashboardLastTab"
        static let dashboardDefaultTab      = "settings.general.dashboardDefaultTab"
        static let dashboardTransitionStyle = "settings.general.dashboardTransitionStyle"
    }
    enum NotchBar {
        static let leftWidgets  = "settings.notchBar.leftWidgets"
        static let rightWidgets = "settings.notchBar.rightWidgets"
        static let hideWidgets  = "settings.notchBar.hideWidgets"
    }
    enum Overview {
        static let showApps          = "settings.overview.showApps"
        static let showTimeDate      = "settings.overview.showTimeDate"
        static let showSystemInfo    = "settings.overview.showSystemInfo"
        static let showPomodoro      = "settings.overview.showPomodoro"
        static let showWeather       = "settings.overview.showWeather"
        static let hideAppNames      = "settings.overview.hideAppNames"
        static let pomodoroDuration  = "settings.overview.pomodoroDuration"
        static let weatherTemperature  = "settings.overview.weatherTemperature"
        static let weatherSymbolName   = "settings.overview.weatherSymbolName"
        static let weatherConditionText = "settings.overview.weatherConditionText"
        static let weatherLastFetch     = "settings.overview.weatherLastFetch"
        static let weatherLastLat       = "settings.overview.weatherLastLat"
        static let weatherLastLon       = "settings.overview.weatherLastLon"
    }
    enum Music {
        static let showSkipButtons = "settings.music.showSkipButtons"
        static let showVisualizer  = "settings.music.showVisualizer"
    }
}
