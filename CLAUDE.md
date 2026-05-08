# OpenNotch — Claude Context

## App identity

The app is called **OpenNotch**. The Xcode project and folder structure still uses `DynamicNotch` as the identifier/bundle prefix; do not rename those.

## References

OpenNotch is inspired by and references two open-source projects:

- **[DynamicNotch](https://github.com/MrKai77/DynamicNotch)** by MrKai77 — foundational notch overlay architecture and window management approach.
- **[BoringNotch](https://github.com/TheBoredTeam/boring.notch)** by TheBoredTeam — UI patterns for music player, audio spectrum visualizer, HUD interception, and feature set inspiration.

## Architecture overview

- `NSNonactivatingPanel` transparent 1000×1000pt canvas anchored to the top of the screen — this is the notch overlay window.
- `NotchEngine` drives a queue-based state machine; features enqueue themselves and the engine serializes presentation.
- `NotchViewModel` is the SwiftUI binding layer. `NotchEventCoordinator` routes OS events to feature handlers.
- `SettingsViewModel` is a facade over multiple `*SettingsStore` objects (`ApplicationSettingsStore`, `MediaAndFilesSettingsStore`, etc.).
- Settings are persisted via `UserDefaults` using `@AppStorage` (in views) and `@Published` wrapped keys (in store classes).

## Key files

| File | Purpose |
|---|---|
| `Features/Notch/NotchView.swift` | Main notch UI, OverviewView, MusicPlayerView, CalendarTabView, MiniCalendarView, CalendarEventPane, PinnedAppsStore, PomodoroViewModel, DashboardTab, NotchBarWidget |
| `Features/Notch/AudioSpectrumView.swift` | Audio spectrum visualizer (4-bar CAShapeLayer NSView + SwiftUI wrapper) |
| `Features/NowPlaying/NowPlayingViewModel.swift` | Now-playing state, artwork loading, app-icon fallback, skip(seconds:) |
| `Features/Settings/Root/SettingsRootView.swift` | Settings window shell, navigation, toolbar |
| `Features/Settings/Root/SettingsRootSections.swift` | Section/group enum declarations and descriptors |
| `Features/Settings/Application/GeneralSettingsView.swift` | Startup, display, language, appearance |
| `Features/Settings/Application/InterfaceSettingsView.swift` | Dashboard layout, overview/music sub-settings, pinned apps |
| `Features/Settings/Application/NotchSettingsView.swift` | Notch appearance, pill widget selection, hide-widgets toggle |
| `Features/Settings/Permissions/SettingsPermissionController.swift` | Permission state for accessibility, Bluetooth, screen capture, calendar |
| `Features/Settings/Shared/Components/SettingsToggleRow.swift` | Reusable icon+toggle row (description is optional) |
| `Features/Settings/Shared/Components/SettingsMenuRow.swift` | Reusable title+dropdown row (description is optional) |

## Settings storage conventions

Two systems coexist:

1. **`@AppStorage` in views** — used for new overview keys (`settings.overview.*`). Reads and writes happen directly in the view.
2. **`ApplicationSettingsStore` (`@ObservedObject`)** — used for older keys like `dashboardOpenMode`, `dashboardDisabledTabs`, `overviewPomodoroDuration`. These are `@Published` properties on the store class.

Both write to the same `UserDefaults` suite, so `OverviewView` (which uses `@AppStorage`) stays in sync with settings views (which use the store).

## Overview/dashboard layout

`OverviewView` (inside `NotchView.swift`) renders four sections:
- `quickAppsSection` — adaptive grid (2/3/4 cols) of up to 12 pinned apps via `PinnedAppsStore`
- `timeDateSection` — large clock (44pt), date (12pt), optional weather
- `systemInfoSection` — CPU/RAM/disk bars, font scales between 13–18pt based on pomodoro visibility
- `pomodoroSection` — countdown + inline +/− duration when state is `.idle` or `.work`

Grid column logic lives in `gridColumnCount(_ count: Int) -> Int`.

## Pill widget bar

`NotchBarWidget` enum: `networkSpeed`, `cpu`, `memory`, `disk`.

- Left side: up to 2 widgets, stored as ordered comma-separated string in `@AppStorage("settings.notchBar.leftWidgets")`.
- Right side: same structure, `@AppStorage("settings.notchBar.rightWidgets")`.
- FIFO on overflow: when adding a 3rd widget, `removeFirst()`.
- `networkSpeed` is mutually exclusive with ring widgets — selecting it clears all others on that side; selecting a ring widget clears networkSpeed.
- `networkSpeed` is always rendered as text; others render as `ProgressRing` via shared `pillRingView(for:)`.
- Master hide toggle: `@AppStorage("settings.notchBar.hideWidgets")` — hides all widgets on both sides when true.

## Settings sidebar structure

The settings window uses an icon-only left sidebar (64px wide, nookx-inspired) with 8 sections:
General · Permissions · Notch · 界面 · Media · Connectivity · System · Lock Screen

The bottom of the sidebar has a donation placeholder (heart icon, currently does nothing).

**Merged sections** — multiple old sections are combined into one settings page:
- `media` = NowPlaying + Downloads + Drop  (all use `MediaAndFilesSettingsStore`)
- `connectivity` = Bluetooth + Network + Focus  (all use `ConnectivitySettingsStore`)
- `system` = Battery + HUD + Timer + ScreenRecording  (multiple stores)

Each individual view exposes `@ViewBuilder var cards: some View` containing its card content without the `SettingsPageScrollView` wrapper. The merged views call `.cards` on each sub-view.

To add a new settings section:
1. Add a `case` to `SettingsRootViewModel.Section` in `SettingsRootSections.swift`
2. Add a `SettingsSectionDescriptor` in `SettingsSectionCatalog.sectionDescriptor(for:)`
3. Add a `case .newSection:` branch in `SettingsRootView.detailView(for:)`

To add content to an existing merged section (e.g., add new cards to `media`):
- Create the new view with a `cards` property
- Call `.cards` from inside `MediaSettingsView.body`

The sidebar selection state uses `Color.accentColor` for highlighting (no per-section tints in the sidebar). The `tint` property in descriptors is available for future use.

## DashboardTab

`DashboardTab` is a `String`-backed enum (cases: `overview`, `nowPlaying`, etc.) used for the `dashboardDisabledTabs: Set<String>` store property. To check if a tab is enabled: `!applicationSettings.dashboardDisabledTabs.contains(tab.rawValue)`.

## Calendar tab

`CalendarTabView` (in `NotchView.swift`) is a three-state view:
- `.notDetermined` — shows a permission request button that calls `store.requestAccess()`
- `.denied / .restricted` — shows a button that calls `store.openPrivacySettings()` (opens System Settings > Privacy > Calendars)
- `authorized / fullAccess / writeOnly` — renders a horizontal split: `MiniCalendarView` (162pt wide) + `CalendarEventPane`

`MiniCalendarView` — month grid with Monday-first weekday header (rotated from `Calendar.veryShortWeekdaySymbols`), chevron navigation via `navigate(_ offset: Int)`, taps set `selectedDate`.

`CalendarEventPane` — event list for the selected date, sourced from `CalendarStore.events`; observes `store.version` to refresh when events change.

`CalendarStore` — `@StateObject` managing `EKEventStore`, `authStatus: EKAuthorizationStatus`, `events: [EKEvent]`, `version: Int` (incremented on reload), `requestAccess()`, `openPrivacySettings()`, `load(for date: Date)`.

`SettingsPermissionController` also tracks `calendarAuthStatus: EKAuthorizationStatus` and exposes a calendar `PermissionItem` in `permissionItems`.

## Music tab

`MusicPlayerView` (in `NotchView.swift`) reads two `@AppStorage` keys:
- `settings.music.showSkipButtons` — shows ±15s skip buttons (`gobackward.15` / `goforward.15`) flanking the transport controls; calls `nowPlayingViewModel.skip(seconds:)`.
- `settings.music.showVisualizer` — shows `AudioSpectrumView` (4-bar animated spectrum) inline with the artist label.

`AudioSpectrumView` wraps `AudioSpectrumNSView` (internal `NSView`): 4 `CAShapeLayer` bars, 0.3s `Timer`, `CABasicAnimation("transform.scale.y")` with random scale 0.35–1.0, 24fps cap via `CAFrameRateRange`.

Artwork falls back to the playing app's icon (`NSWorkspace.shared.icon(forFile:)` at 256×256) when no `artworkData` is available from MediaRemote (e.g., web players in Edge/Chrome).

Both settings are toggled in **设置 › 界面 › 仪表盘 › 音乐** via `SubToggleRow` (no icon badge).

## Localization

`locale.dn(_:fallback:)` is the extension used throughout settings for string lookup. The `fallback:` parameter is the English string shown if the key is missing from the localization file.
