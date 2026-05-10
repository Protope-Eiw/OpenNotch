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
| `Features/Notch/NotchView.swift` | Main notch UI, pill strip, side widgets, dashboard toggle, NotchEventHandlersView, ProgressRing — extracted sub-views live in `Dashboard/` |
| `Features/Notch/Dashboard/DashboardTab.swift` | `DashboardTab` enum + icon/title/description extensions |
| `Features/Notch/Dashboard/DashboardPanelView.swift` | Dashboard container: swipe navigation, tab pages, system tab (gauge & speed cards) |
| `Features/Notch/Dashboard/OverviewView.swift` | Overview tab: pinned apps grid, time/date/weather, system info, pomodoro column |
| `Features/Notch/Dashboard/MusicPlayerView.swift` | Now-playing tab: artwork, progress bar, playback controls |
| `Features/Notch/Dashboard/CalendarTabView.swift` | Calendar tab: MiniCalendarView, CalendarEventPane, CalendarStore |
| `Features/Notch/Dashboard/AppLauncherView.swift` | App Launcher tab: search bar, adaptive grid, AppIconButton |
| `Features/Notch/Dashboard/PomodoroViewModel.swift` | Pomodoro timer state machine (ObservableObject) |
| `Features/Notch/Dashboard/EventMonitorViews.swift` | ClickOutsideMonitor, SwipeEventMonitor (NSViewRepresentable) |
| `Features/Notch/AudioSpectrumView.swift` | Audio spectrum visualizer (4-bar CAShapeLayer NSView + SwiftUI wrapper) |
| `Features/Notch/NotchViewModel.swift` | ViewModel for notch sizing, swipe interaction, content transitions |
| `Features/Notch/NotchEngine.swift` | Queue-based state machine for live activity presentation |
| `Features/Notch/NotchBarWidget.swift` | Widget enum: networkSpeed, cpu, memory, disk |
| `Features/Notch/Core/Models/NotchModel.swift` | Single source of truth for notch geometry (idle size, live activity, temporary notification) |
| `Features/NowPlaying/NowPlayingViewModel.swift` | Now-playing state, artwork loading, app-icon fallback, skip(seconds:) |
| `Features/Onboarding/` | Onboarding welcome flow (3 steps, triggered on first launch) |
| `Features/Settings/Root/SettingsRootView.swift` | Settings window shell, left icon-only sidebar (64px), navigation |
| `Features/Settings/Root/SettingsRootSections.swift` | Section/group enum declarations and descriptors |
| `Features/Settings/Application/GeneralSettingsView.swift` | Startup, display, language, appearance |
| `Features/Settings/Application/InterfaceSettingsView.swift` | Dashboard layout, overview/music sub-settings, pinned apps |
| `Features/Settings/Application/NotchSettingsView.swift` | Notch appearance, pill widget selection, hide-widgets toggle |
| `Features/Settings/Application/DebugSettingsView.swift` | Debug previews: simulate events, trigger onboarding, sequence testing |
| `Features/Settings/Permissions/SettingsPermissionController.swift` | Permission state for accessibility, Bluetooth, screen capture, calendar |
| `Features/Settings/Shared/Components/SettingsToggleRow.swift` | Reusable icon+toggle row |
| `Features/Settings/Shared/Components/SettingsMenuRow.swift` | Reusable title+dropdown row |

## UI Areas

### 1. Notch 信号区域 (Notch Signal Area)

Mac 屏幕上方物理黑边区域。除 idle 状态的 pill strip 外，还可临时展开显示通知/信号：

- **Live Activities** — 持久性活动，如播放歌曲、下载文件、计时器
- **Temporary Notifications** — 一次性通知，如 AirDrop、蓝牙连接、断网、电量变化、锁屏等
- 展开高度由 `NotchContentProtocol.size()` / `expandedSize()` 决定（参见下方"Notch 向下展开"）
- `NotchEngine` 队列状态机负责串行化展示，feature 将自身 enqueue，引擎逐个呈现
- `NotchModel` 是 `size` 的单一数据源，`NotchViewModel.presentedNotchSize` 驱动 SwiftUI 布局

### 2. 两侧 Widget 区域 (Side Widgets)

物理 notch 左右两侧的小组件，用户可在设置（NotchSettingsView）中自选布局。

- `NotchBarWidget` enum: `networkSpeed`, `cpu`, `memory`, `disk`
- 左侧最多 2 个，存储在 `@AppStorage("settings.notchBar.leftWidgets")`
- 右侧最多 2 个，存储在 `@AppStorage("settings.notchBar.rightWidgets")`
- FIFO 溢出：添加第 3 个时自动移除最旧的
- `networkSpeed` 与环形 widget 互斥（选中一个自动清除另一侧）
- `networkSpeed` 渲染为文字，其余渲染为 `ProgressRing`
- 全局隐藏开关：`@AppStorage("settings.notchBar.hideWidgets")`
- `notchExpandedDownward` 为 true 时自动隐藏侧边 widget

### 3. Dashboard 区域

通过点击/悬停 notch 或两侧 widget 区域打开的面板。

**打开方式：**
- **点击模式**（`dashboardOpenMode = .tap`）：点击 notch 或侧边 widget 区域切换打开/关闭
- **悬停模式**（`dashboardOpenMode = .hover`）：鼠标移入 notch 区域 200ms 后打开，移出 120ms 后关闭

**布局：**
- **左上角**：所有 dashboard tab 的水平排列（`DashboardTab` 枚举成员），可左右滑动切换，支持拖拽排序
- **右上角**：齿轮设置按钮，点击打开设置窗口
- **中间区域**：当前 tab 的内容面板
- 面板高度：大多数 tab = 173pt，apps tab = 519pt

**Tab 切换：**
- 左右滑动（`SwipeEventMonitor`）或点击顶部 tab 标签
- 动画：`.spring(response: 0.35, dampingFraction: 0.85)`

**DashboardTab 枚举：** `overview`, `music`, `system`, `calendar`, `apps`
- 用户可通过设置禁用某些 tab（`dashboardDisabledTabs: Set<String>`）

### 4. Notch 向下展开 (Notch Downward Expansion)

Idle 状态下 notch 只有 pill 高度（~37pt，即 `baseHeight`）。当有 live activity 或临时通知时，notch body 向下延伸显示内容。这是独立于 dashboard 的展开路径（`notchExpandedDownward` 显式排除了 `dashboardOpen` 状态）。

**展开场景：**

| 场景 | 类型 | 展开高度 | 源码 |
|---|---|---|---|
| **Onboarding 第 2/3 步** | live activity | +140pt | `OnboardingSteps.swift` |
| **Onboarding 第 1 步** | live activity | +120pt | `OnboardingSteps.swift` |
| NowPlaying 展开 | live activity expanded | +160pt | `NowPlayingNotchContent.swift` |
| Download 展开 | live activity expanded | +120pt | `DownloadNotchContent.swift` |
| TrayActive 展开 | live activity expanded | +115pt | `TrayActiveNotchContent.swift` |
| Timer 展开 | live activity expanded | +70pt | `TimerNotchContent.swift` |
| No Internet | temporary notification | +120pt | `NoInternetConnectionContent.swift` |
| AirDrop | temporary notification | +110pt | `AirDropNotchContent.swift` |
| 电池（详细） | temporary notification | +70~75pt | `FullPowerNotchContent.swift`, `LowPowerNotchContent.swift` |
| Focus / ScreenRecording / LockScreen / 蓝牙等 | live activity | +0pt（仅横向展开） | 各 `NotchContent` 实现 |

**效果：**
- `notchExpandedDownward = !dashboardOpen && notchViewModel.presentedNotchSize.height > baseHeight`
- 侧边 widget 快速隐藏（`.easeIn(duration: 0.12).delay(0.04)`）
- 阻止 dashboard 通过 hover/tap 打开
- 展开结束后，侧边 widget 延迟重新显示（等待弹簧动画结束）

**Onboarding 流程：** 首次启动时 `NotchEventCoordinator.checkFirstLaunch()` 触发，三步引导（欢迎→权限→支持）。

**Debug 预览：** `DebugSettingsView`（`#if DEBUG` 保护）可模拟所有通知类型和展开高度。

## Settings storage conventions

Two systems coexist:

1. **`@AppStorage` in views** — used for new overview keys (`settings.overview.*`). Reads and writes happen directly in the view.
2. **`ApplicationSettingsStore` (`@ObservedObject`)** — used for older keys like `dashboardOpenMode`, `dashboardDisabledTabs`, `overviewPomodoroDuration`. These are `@Published` properties on the store class.

Both write to the same `UserDefaults` suite, so `OverviewView` (which uses `@AppStorage`) stays in sync with settings views (which use the store).

## Overview/dashboard layout

`OverviewView` (in `Features/Notch/Dashboard/OverviewView.swift`) renders four sections:
- `quickAppsSection` — adaptive grid (2/3/4 cols) of up to 12 pinned apps via `PinnedAppsStore`
- `timeDateSection` — large clock (44pt), date (12pt), optional weather
- `systemInfoSection` — CPU/RAM/disk bars, font scales between 13–18pt based on pomodoro visibility
- `pomodoroSection` — countdown + inline +/− duration when state is `.idle` or `.work`

Grid column logic lives in `gridColumnCount(_ count: Int) -> Int`.

## Pill widget bar

`NotchBarWidget` enum: `networkSpeed`, `cpu`, `memory`, `disk`.

- Left side: up to 2 widgets, stored as ordered comma-separated string in `@AppStorage("settings.notchBar.leftWidgets")`.
- Right side: same structure, `@AppStorage("settings.notchBar.rightWidgets")`.
- User-configurable in **NotchSettingsView** — can select which widgets to show and their order.
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

`DashboardTab` is a `String`-backed enum (cases: `overview`, `music`, `system`, `calendar`, `apps`). Located in `Features/Notch/Dashboard/DashboardTab.swift`. Used for `dashboardDisabledTabs: Set<String>` store property. To check if a tab is enabled: `!applicationSettings.dashboardDisabledTabs.contains(tab.rawValue)`.

## Calendar tab

`CalendarTabView` (in `Features/Notch/Dashboard/CalendarTabView.swift`) is a three-state view:
- `.notDetermined` — shows a permission request button that calls `store.requestAccess()`
- `.denied / .restricted` — shows a button that calls `store.openPrivacySettings()`
- `authorized / fullAccess / writeOnly` — renders `MiniCalendarView` (162pt) + `CalendarEventPane`

`MiniCalendarView` — month grid, chevron navigation, taps set `selectedDate`.
`CalendarEventPane` — event list for selected date, sources from `CalendarStore.events`.
`CalendarStore` — `@StateObject` managing `EKEventStore`, `authStatus`, `events`, `version`.

## Music tab

`MusicPlayerView` (in `Features/Notch/Dashboard/MusicPlayerView.swift`) reads two `@AppStorage` keys:
- `settings.music.showSkipButtons` — ±15s skip buttons
- `settings.music.showVisualizer` — `AudioSpectrumView` (4-bar animated spectrum)

Artwork falls back to `NSWorkspace.shared.icon(forFile:)` when no `artworkData` is available.

## Localization

`locale.dn(_:fallback:)` is the extension used throughout settings for string lookup.

---

## TODOs

### Dashboard 打开速度差异
点击 notch 区域打开 dashboard 非常丝滑快捷，而点击两侧 widget 区域打开则明显变慢。需要排查 gesture 响应链路中的延迟原因。

### 权限页面状态实时更新
设置 → 权限 页面中，各权限的状态（Accessibility、Bluetooth、Screen Recording、Calendar）不是实时刷新的。当前依靠 `NSApplication.didBecomeActiveNotification` 和 2 秒轮询，但用户从系统设置授权后切回来时可能存在 TCC 延迟，且 2 秒轮询间隔内 UI 不会更新。需要更可靠的刷新机制。

### 设置侧边栏点击判定区域过小
设置窗口左侧 icon-only 导航栏（64px 宽）需要精确点到图标才能切换，判定区域太小。应当适当增大点击命中区域。

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
- Create new View in `Features/Notch/Dashboard/`
- Tab content height: `dashboardPanelHeight` computed property (apps tab = 519pt, others = 173pt)
