# OpenNotch — Agent Context

> 本文档是给 AI agent（opencode）看的上下文记忆。记录问题、计划、区域说明等内容时请附带对应的文件路径和代码位置，方便后续快速定位。

当我说整体过一遍项目时，指的是通读整个项目代码，看看代码中有什么可以优化的，功能中有什么比较鸡肋的可以砍掉的，排版布局有什么可以美化的。

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

### 5. Notch 通知系统 (Notification System)

`NotchModel` 有两个内容槽位：
- `liveActivityContent` — 常驻内容，持续显示直到被关闭或被更高优先级替换
- `temporaryNotificationContent` — 临时通知，自动消失，始终优先于常驻内容

**事件链路：** 系统事件 → `Core/Services/` monitor → ViewModel `@Published` event → `NotchEventHandlersView.onReceive` → `NotchEventCoordinator.handle*Event()` → 各 `Notch*EventsHandler` → `notchViewModel.send(.showLiveActivity/showTemporaryNotification)` → `NotchEngine` 队列 → `NotchModel` 存储 → `NotchView` 渲染

**全部事件源：**

| 事件源 | Event 值 | 槽位 | 触发场景 |
|---|---|---|---|
| 电源 | `.charger` / `.lowPower` / `.fullPower` | 临时 | 插拔充电器、电量低、充满 |
| 蓝牙 | `.connected` | 临时 | 蓝牙设备连接 |
| 网络 | `.wifiConnected` / `.vpnConnected` / `.hotspotActive` / `.noInternetConnection` | 临时/常驻 | Wi-Fi/VPN/热点/断网 |
| 下载 | `.started` / `.stopped` | 常驻 | 浏览器文件下载 |
| AirDrop | `.dragStarted` / `.dragEnded` / `.dropped` | 常驻 | 拖拽文件靠近/放下 |
| NowPlaying | `.started` / `.stopped` / `.playbackStateChanged` | 常驻 | 音乐/视频播放 |
| 专注 | `.FocusOn` / `.FocusOff` | 常驻/临时 | 专注模式开关 |
| 计时器 | `.started` / `.updated` / `.stopped` | 常驻 | 系统计时器 |
| 录屏 | `.started` / `.stopped` | 常驻 | 屏幕录制 |
| 锁屏 | `.started` / `.stopped` | 常驻 | 锁定/解锁 |
| HUD | `.display(Int)` / `.keyboard(Int)` / `.volume(Int)` | 临时 | 亮度/键盘灯/音量 |
| NotchSize | `.width` / `.height` | 临时 | 设置中尺寸预览 |

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

### Dashboard 滑动溢出
slide 模式下左右切换 tab 时，某些组件会从 dashboard 区域的左/右边缘露出。

**溢出条件：**
- 只发生在 **overview ↔ music** 之间的滑动
- 其他 tab（system、calendar、apps）之间切换不存在溢出
- 具体溢出组件：
  - **Music 海报封面** — `artworkView` 中背景模糊层 `scaleEffect(x: 1.4, y: 1.5)` + `blur(radius: 22)` 渲染范围远超视图边界
  - **Overview 番茄钟** — `Circle().fill(...)` 被 `.frame(maxWidth: .infinity)` 撑大，超过 116×116 可视范围
- 溢出方向：music→system 时海报从左侧露出；system→overview 时番茄钟从右侧露出
- 不溢出的是 0c64aba 的 ZStack+opacity 方案（即现在的 fade 模式）
- ~快速双指同方向滑动两下时，第二次滑动识别不到（SwipeEventMonitor 的 didFire 可能未正确重置）~ ✅ 已修复

**已修复**：<br>
| 尝试 | 结果 | 根因 |
|------|------|------|
| `lockedContentWidth` 锁定宽度 | ❌ | 捕获时机在动画中途 |
| `mask(Rectangle())` 在 GeometryReader 外层 | ❌ | 裁切与内部 ZStack 动画不同步 |
| `compositingGroup().clipShape(Rectangle())` 在 ZStack 上 | ❌ | 裁切基于 layout 坐标空间，无法裁切 offset 后的 visual 内容 |
| 每个 tab page 单独 `.clipShape(Rectangle())` 后再 `.offset()` | ✅ | 每个 tab 裁切到自己的 W 宽 layout frame，溢出在 offset 前被切除 |

### 音乐海报停止播放时黑色方块闪烁 + 滑动溢出

**现象**：暂停/开始播放时可见正方形边框背景（矩形过渡痕迹）；滑动切 tab 时模糊溢出到相邻 tab。

**根因**：
- 三个层使用不同 clip/bound：Layer 1 模糊是满矩形，Layer 2/3 是圆角矩形 → 角落过渡雾状⇄透明产生方框感
- 模糊层 `scaleEffect(x: 1.4, y: 1.5)` 溢出 artwork ZStack 范围，slide 模式下穿入相邻 tab

**已修复**（参照 BoringNotch 方案重构）：
1. ZStack 统一 `.clipShape(RoundedRectangle(cornerRadius: 12))` — 三层共享同一圆角边界，无方框，无溢出
2. Layer 1 模糊 radius 从 22 增加到 30，让裁边不可见
3. Layer 3 改为 `Rectangle().blur(radius: 50).opacity(0.6)` — 遮罩边缘 50pt 模糊羽化，过渡平滑
4. 移除 Layer 1 独立 clipShape，移除 Layer 3 的 RoundedRectangle

### Dashboard 打开速度差异
点击 notch 区域打开 dashboard 非常丝滑快捷，而点击两侧 widget 区域打开则明显变慢。需要排查 gesture 响应链路中的延迟原因。

### 权限页面状态实时更新
设置 → 权限 页面中，各权限的状态（Accessibility、Bluetooth、Screen Recording、Calendar）不是实时刷新的。当前依靠 `NSApplication.didBecomeActiveNotification` 和 2 秒轮询，但用户从系统设置授权后切回来时可能存在 TCC 延迟，且 2 秒轮询间隔内 UI 不会更新。需要更可靠的刷新机制。

**已修复：**
- 轮询改为可控的 `startPolling()` / `stopPolling()`，权限页面 `onAppear` 时开始，`onDisappear` 时停止
- 点击授权按钮后启动**激进刷新策略**（连续 10 秒每 500ms 刷新一次）
- 修复了设置窗口关闭后 Timer 继续运行的资源浪费问题

### 设置侧边栏点击判定区域过小
设置窗口左侧 icon-only 导航栏（64px 宽）需要精确点到图标才能切换，判定区域太小。

**已修复：** `VStack(spacing: 4)` → `spacing: 0`，button `minHeight: 44` → `48` 吸收间距，label 和 Button 两层都加 `.frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())`，确保整列无死区。

### 翻译问题
设置界面一/二/三级标题及各个选项的文案不统一，且不跟随设置中选择的语言走。需要排查 `locale.dn(_:fallback:)` 的使用范围，确保所有用户可见字符串都走 i18n 流程。

### 设置选项行间距与图标冗余
设置中有些选项行与行之间排列紧密，且部分图标意义不大或不必要。需要整体梳理 settings 各页面的间距和 icon 使用，移除冗余图标。

**已修复：** `a721cdb` 设置侧边栏重构时统一了 `SettingsCardView` 布局，固定了 `SubToggleRow` 最小高度，移除了 Pomodoro 行多余图标。

### 下拉菜单改为左右胶囊切换
Interface → 仪表盘中的"打开模式"（dashboardOpenMode）和 "Transition Style" 等只有两个选项的下拉菜单，不如改成类似左右胶囊的切换控件（segmented control），用户单击即可切换，减少操作步骤。

**已修复：** 新增 `SettingsSegmentedRow` 组件，替换了 `InterfaceSettingsView` 中 dashboardOpenMode 和 dashboardTransitionStyle 的 `SettingsMenuRow`。

### Connectivity 页面功能测试
Connectivity 界面中的 Bluetooth、Network、Focus 等功能尚未进行充分测试。需要确认各功能的状态读取是否正确、交互是否正常。

### Dashboard Tab 切换动画不一致
✅ 已修复：非相邻 tab 点击直接 snap（无动画），相邻 tab 保持 slide/fade 动画。

### Dashboard 日历排版 + 事件编辑
✅ 已修复：日历左间距 +12pt，右侧事件面板临时替换为"开发中，敬请期待"占位。

### 上方常驻播放器界面
如何实现部分用户想要的上方常驻播放器界面（类似菜单栏播放器）？感觉和现有的 NowPlaying 功能有重叠，需要评估是否复用现有 music tab / live activity 的方案，还是另起新入口。

### Notch 功能（刘海内展开组件）全面调查

刘海内容通过 `NotchModel` 的两个槽位驱动：
- `liveActivityContent` — 常驻内容，持续显示直到被关闭或被更高优先级替换
- `temporaryNotificationContent` — 临时通知，自动消失，始终优先于常驻内容 `NotchEngine.swift`

引擎维护 `activeLiveActivities` 按优先级排序，同一时刻只显示一个 (`NotchEngine.swift`).

**与两侧 widget 的区别**：两侧 widget 保持常驻显示，notch 功能触发时会被挤开。

#### 全部 23 种内容类型（11 个栈）

| # | 内容 | 栈 ID | 类型 | 优先级 | 代码位置 |
|---|---|---|---|---|---|
| **🔋 电源** | | | | |
| 1 | 充电提示 | `battery.charger` | 临时 | 0 | `Battery/Content/ChargerNotchContent.swift` |
| 2 | 低电量警告 | `battery.lowPower` | 临时 | 0 | `Battery/Content/LowPowerNotchContent.swift` |
| 3 | 已充满提示 | `battery.fullPower` | 临时 | 0 | `Battery/Content/FullPowerNotchContent.swift` |
| **📡 网络** | | | | |
| 4 | 蓝牙已连接 | `bluetooth.connected` | 临时 | 0 | `Bluetooth/Content/BluetoothConnectedNotchContent.swift` |
| 5 | 个人热点 | `hotspot.active` | 常驻 | 2* | `Network/Hotspot/HotspotActiveContent.swift` |
| 6 | Wi-Fi 已连接 | `wifi.connected` | 临时 | 0 | `Network/WiFi/WifiConnectedNotchContent.swift` |
| 7 | VPN 已连接 | `vpn.connected` | 临时 | 0 | `Network/VPN/VpnConnectedNotchContent.swift` |
| 8 | 无网络连接 | `network.noInternetConnection` | 临时(∞) | 0 | `Network/NoInternetConnection/NoInternetConnectionContent.swift` |
| **🎬 HUD** | | | | |
| 9 | 亮度/音量/键盘灯 | `hud.system` / `hud.keyboard` | 临时 | 0 | `HUD/Content/HudNotchContent.swift` |
| **🎵 媒体** | | | | |
| 10 | NowPlaying 海报+音浪 | `nowPlaying` | 常驻 | 5* | `NowPlaying/Content/NowPlayingNotchContent.swift` |
| 11 | 下载进度 | `download.active` | 常驻 | 3* | `Download/Content/DownloadNotchContent.swift` |
| 12 | 计时器 | `clock.timer` | 常驻 | 6* | `Timer/Content/TimerNotchContent.swift` |
| **🎯 专注** | | | | |
| 13 | 专注模式开启 | `focus.on` | 常驻 | 1* | `Focus/Content/FocusOnNotchContent.swift` |
| 14 | 专注模式关闭 | `focus.off` | 临时 | 0 | `Focus/Content/FocusOffNotchContent.swift` |
| **🔴 录屏** | | | | |
| 15 | 录屏指示器 | `screen.recording` | 常驻 | 7* | `ScreenRecording/ScreenRecordingContent.swift` |
| **📁 拖放** | | | | |
| 16 | AirDrop 靠近 | `airdrop` | 常驻 | 1002 | `DragAndDrop/AirDrop/Content/AirDropNotchContent.swift` |
| 17 | 文件托盘 | `tray` | 常驻 | 1002 | `DragAndDrop/Tray/Content/TrayNotchContent.swift` |
| 18 | AirDrop+托盘联合 | `dragAndDrop.combined` | 常驻 | 1002 | `DragAndDrop/Content/DragAndDropCombinedNotchContent.swift` |
| 19 | 托盘有内容 | `tray.active` | 常驻 | 4* | `DragAndDrop/Tray/Content/TrayActiveNotchContent.swift` |
| **🔒 锁屏** | | | | |
| 20 | 锁定/解锁图标 | `lockScreen` | 常驻 | 1003 | `LockScreen/Content/LockScreenNotchContent.swift` |
| **⚙️ 尺寸校准** | | | | |
| 21 | Notch 宽度调节 | `notchSize.width` | 临时 | 1000 | `Notch/Content/NotchSizeContent.swift` |
| 22 | Notch 高度调节 | `notchSize.height` | 临时 | 1001 | `Notch/Content/NotchSizeContent.swift` |
| **👋 引导** | | | | |
| 23 | Onboarding 三步教程 | `onboarding` | 常驻 | 1004 | `Onboarding/Content/OnboardingNotchContent.swift` |

> `*` = 用户可在 Settings → 优先级中自定义 (0-20)。1000+ 为硬编码不可配置。
> 所有文件均在 `OpenNotch/Features/` 下。
> 注册中心：`Core/Models/NotchContentRegistry.swift`
> 引擎：`Features/Notch/NotchEngine.swift`

#### 已知问题
2. **充电动画抽搐**：`ChargerNotchContent` 显示时动画表现为 开始→取消→再开始→正常

**已修复：**
- 解锁图标遮挡：`LockScreenNotchContent.size()` compact 宽度从 +55 增至 +62，为 `lock.open.fill` 右侧搭扣留出空间

**已修复：**
- `PowerViewModel`: `@Published` 改为 `PassthroughSubject`（事件是一次性的，不保存状态）
- 添加 100ms 防抖：短时间内多次触发同一事件只发送一次
- `lastSentEvent` 追踪防止重复发送相同事件
- 根本原因：插入电源时 IOKit 可能在极短时间内发送多个电源状态更新通知

### 两侧 widget 环形图标优化
Notch 左右两侧 widget 的 `ProgressRing`（CPU/MEM/DISK 环形）中的内部图标偏大，且颜色未随占用率变化（如 CPU > 80% 时变红）。需要：缩小内部 SF Symbol 尺寸，让 ring 的进度更明显；绑定 `Color.thresholdColor` 使环和图标颜色随占用率动态变化。

**已修复：** `pillRingView(for:)` 已使用 `Color.pillColor()` 做阈值着色（CPU 50/80, MEM 70/85, DSK 80/90），文字替代了旧版 SF Symbol，字体已缩小到 9pt 数值 + 6pt 标签。

### 通知事件触发全面失效
连接电源时 notch 通知组件不显示。Debug → Trigger Events 中蓝牙连接、已连接 Wi-Fi、无互联网连接、VPN 已连接点击后均无任何事件触发。充电功能虽然在 debug 界面可触发，但真正插拔充电器时也不显示。需要排查 `NotchEventCoordinator` → 各 feature `*ViewModel` → `NotchEngine` 的链路，确认事件是否到达 engine 以及 `NotchModel.content` 是否正确更新。特别关注外接显示器场景（TODO 另有记录）。

**已修复：** `9d55053` — PowerViewModel 移除 `lastSentEvent` 守卫（充电/低电/满电可重复触发），DebugSettingsViewModel 绕过 coordinator guard 直接 send，HUDSettingsStore 默认值 fallback 修复。

### Dashboard music 播放时封面在 Overview 右侧渲染
✅ 已修复：根因为 slide layout 中 tab 页面的模糊/缩放内容溢出到相邻 tab。每个 tab page 单独加 `.clipShape(Rectangle())` 后再 `.offset()`，实现"隔断"。

### 刘海通知和展开功能仅限内置显示器
目前所有的刘海区域通知功能（live activities、temporary notifications）和刘海向下展开功能都只能在内置显示器上显示，外接显示器无法触发 notch 内容展示。需要排查 `NotchEventCoordinator` 和 `NotchEngine` 中是否存在显示器过滤逻辑或假定了特定显示器为 notched display 的代码路径。

### 动画速度设置有效性
设置 → 刘海 → 动画中的"动画速度"（NotchAnimationPreset：snappy/fast/balanced/slow/relaxed）尚未经过充分测试，不确定各档位之间是否能感受到明显的速度差异。response 从 0.41 到 0.53 跨度不大，可能需要验证是否存在感知差异，或考虑增减档位数量 / 增大范围。

---

### 蓝牙临时活动默认值
✅ 已修复：`GeneralSettingsStorage.swift` 中 `bluetoothTemporaryActivityEnabled` 默认值从 `false` 改为 `true`。

### 设置界面排版：所有 notch 功能集中到一个栏目
当前设置页面中点击 Notch 和系统状态等功能分散在不同栏目，应将所有 notch 相关功能（通知开关、优先级、动画等）归并到统一的栏目下。

### 播放器保持显示时的 widget 策略
播放器可以打开保持显示，但此时 notch 区域功能和左右两侧 widget 是否应该显示？需要决策并实现对应的显示/隐藏逻辑。

### System Status dashboard 排版
✅ 已修复：右栏信息区添加了与 gaugeCard 统一的 `background` + `clipShape` 卡片样式，间距微调，整体更统一。

### 捐赠栏目与全局限定化
捐赠栏目写死了中文文本 '喜欢就请我喝杯咖啡，完全随意☕️'，但已直接替换为英文。很多其他位置也是写死中/英文的，需要整体梳理，确保所有用户可见字符串都通过 `locale.dn(_:fallback:)` 走 i18n 流程。

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
