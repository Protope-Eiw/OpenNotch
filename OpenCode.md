# OpenNotch — Agent Context

## App identity

The app is called **OpenNotch**.

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
| `Features/Notch/NotchViewModel.swift` | ViewModel for notch sizing, swipe interaction, content transitions |
| `Features/Notch/NotchEngine.swift` | Queue-based state machine for live activity presentation |
| `Features/Notch/NotchBarWidget.swift` | Widget enum: networkSpeed, cpu, memory, disk |
| `Features/NowPlaying/NowPlayingViewModel.swift` | Now-playing state, artwork loading, app-icon fallback, skip(seconds:) |
| `Features/Settings/Root/SettingsRootView.swift` | Settings window shell, navigation, toolbar |
| `Features/Settings/Root/SettingsRootSections.swift` | Section/group enum declarations and descriptors |
| `Features/Settings/Application/GeneralSettingsView.swift` | Startup, display, language, appearance |
| `Features/Settings/Application/InterfaceSettingsView.swift` | Dashboard layout, overview/music sub-settings, pinned apps |
| `Features/Settings/Application/NotchSettingsView.swift` | Notch appearance, pill widget selection, hide-widgets toggle |
| `Features/Settings/Permissions/SettingsPermissionController.swift` | Permission state for accessibility, Bluetooth, screen capture, calendar |
| `Features/Settings/Shared/Components/SettingsToggleRow.swift` | Reusable icon+toggle row |
| `Features/Settings/Shared/Components/SettingsMenuRow.swift` | Reusable title+dropdown row |

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
General · Permissions · Notch · Interface · Media · Connectivity · System · Lock Screen

**Merged sections:**
- `media` = NowPlaying + Downloads + Drop (all use `MediaAndFilesSettingsStore`)
- `connectivity` = Bluetooth + Network + Focus (all use `ConnectivitySettingsStore`)
- `system` = Battery + HUD + Timer + ScreenRecording (multiple stores)

Each individual view exposes `@ViewBuilder var cards: some View` without the `SettingsPageScrollView` wrapper. Merged views call `.cards` on each sub-view.

To add a new settings section:
1. Add a `case` to `SettingsRootViewModel.Section` in `SettingsRootSections.swift`
2. Add a `SettingsSectionDescriptor` in `SettingsSectionCatalog.sectionDescriptor(for:)`
3. Add a `case .newSection:` branch in `SettingsRootView.detailView(for:)`

## DashboardTab

`DashboardTab` is a `String`-backed enum (cases: `overview`, `nowPlaying`, etc.). Used for `dashboardDisabledTabs: Set<String>` store property. To check if a tab is enabled: `!applicationSettings.dashboardDisabledTabs.contains(tab.rawValue)`.

## Calendar tab

`CalendarTabView` (in `NotchView.swift`) is a three-state view:
- `.notDetermined` — shows a permission request button that calls `store.requestAccess()`
- `.denied / .restricted` — shows a button that calls `store.openPrivacySettings()`
- `authorized / fullAccess / writeOnly` — renders `MiniCalendarView` (162pt) + `CalendarEventPane`

`MiniCalendarView` — month grid, chevron navigation, taps set `selectedDate`.
`CalendarEventPane` — event list for selected date, sources from `CalendarStore.events`.
`CalendarStore` — `@StateObject` managing `EKEventStore`, `authStatus`, `events`, `version`.

## Music tab

`MusicPlayerView` reads two `@AppStorage` keys:
- `settings.music.showSkipButtons` — ±15s skip buttons
- `settings.music.showVisualizer` — `AudioSpectrumView` (4-bar animated spectrum)

Artwork falls back to `NSWorkspace.shared.icon(forFile:)` when no `artworkData` is available.

## Localization

`locale.dn(_:fallback:)` is the extension used throughout settings for string lookup.

---

## Session History (2026-05-09)

### Stable baseline
- `ff59262` — last clean commit before today's changes
- All later commits introduced widget interaction regressions (DragGesture vs onTapGesture)

### Problems found and fixed
1. **Right-side pill widgets invisible when dashboard closed** — ZStack placeholder used fixed `.frame(width: 220)` which overflowed the 75pt container and clipped the widget. Fix: use `.frame(maxWidth: 220, minHeight: 28)`.
2. **I-beam cursor on right side when dashboard open (non-apps tabs)** — `NSTextField` (via SwiftUI `TextField`) always in view hierarchy, macOS shows I-beam over its frame. Fix: conditionally render search bar with `if dashboardOpen && dashboardTab == .apps`.
3. **Random settings open when clicking right widgets** — `pillRightWidgetView` had its own `.onTapGesture { openWindow }` that competed with the outer container's `.onTapGesture { toggleDashboard() }`. Fix: remove the conflicting gesture from `pillRightWidgetView`.
4. **Dashboard close only via notch or outside** — `guard !dashboardOpen` on side DragGestures prevented close. Left side: remove guard. Right side: keep guard + add `TapGesture(including: .subviews)` with `dragHandledOpen` flag.

### Rollback chain
- Started at `80d199c` → rolled back to `7363e97` → rolled back further to `5115cb4`
- Current HEAD: `5115cb4` + 3 fix commits
- All changes force-pushed to `origin/main`

### Key gesture rules (current)
- **Left side widget area**: `DragGesture(minimumDistance: 0)` — no `dashboardOpen` guard → always toggles
- **Right side widget area**: `DragGesture(minimumDistance: 0)` with `guard !dashboardOpen` + `TapGesture(including: .subviews)` with `dragHandledOpen` flag to prevent double-toggle
- **Gear button**: `.highPriorityGesture(TapGesture())` to prevent parent TapGesture from firing when closing dashboard
- **Notch body**: `DragGesture(minimumDistance: 0)` — always toggles (no guard)
- **Hover mode**: `handleHoverChange()` with 200ms open / 120ms close delay

---

## Planned features (suggested by user)

### System Status dashboard tab
A dedicated dashboard tab showing detailed system health info:
- Live CPU per-core usage chart
- Memory pressure graph
- Disk activity
- Network throughput chart
- Process list (top CPU/memory consumers)
- GPU usage / temperature if available
- Location: new `.systemStatus` case in `DashboardTab` enum

### Calendar tab enhancements
Current calendar tab is minimal. Suggested improvements:
- Week view (horizontal scrolling by week)
- Event creation directly from notch
- Multiple calendar source selection (iCloud, Google, Exchange)
- All-day events visual indicator
- Event notifications / reminders display
- Time zone support
- Search/filter events
- Integration with system calendar alerts

### General architectural notes for new tabs
- Add new `case` to `DashboardTab` enum
- Add `settings.dashboardDisabledTabs` handling in `InterfaceSettingsView`
- Create new View in `NotchView.swift` (the file is already ~2400 lines)
- May want to extract into separate files for maintainability
- Tab content height: `dashboardPanelHeight` computed property (apps tab = 519pt, others = 173pt)
